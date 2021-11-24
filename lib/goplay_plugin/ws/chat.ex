defmodule GoplayPlugin.WS.Chat do
  use WebSockex
  require Logger

  def start_link(setting, callback_pid) do
    ssl_opts = [
      verify: :verify_none,
      versions: [:"tlsv1.1"],
      ciphers: :ssl.cipher_suites(:all, :"tlsv1.1")
    ]

    chat_url =
      if setting.event_host == "goplay.co.id" do
        "wss://gschat.goplay.co.id/chat"
      else
        "wss://g-gschat.goplay.co.id/chat"
      end

    WebSockex.start_link(
      chat_url,
      __MODULE__,
      %{callback_pid: callback_pid, setting: setting},
      ssl_options: ssl_opts
    )
  end

  def handle_connect(_conn, state) do
    Logger.info("chat connect")
    Process.send_after(self(), :monitor, 1000)
    {:ok, state}
  end

  def handle_disconnect(_, state) do
    Logger.info("chat disconnect")
    {:ok, state}
  end

  def handle_frame({:text, msg}, state) do
    with {:ok, msg} <- Jason.decode(msg) do
      handle_text_message(msg, state)
    end
  end

  def terminate(reason, _state) do
    Logger.info("chat terminate #{reason}")
    exit(:normal)
  end

  defp send_message(pid, msg) do
    msg = Jason.encode!(msg)
    WebSockex.send_frame(pid, {:text, msg})
  end

  def join(pid, setting) do
    msg = %{
      ct: 10,
      room_id: setting.room_id,
      token: setting.token,
      recon: setting.recon
    }

    send_message(pid, msg)
    :ok
  end

  def handle_info(:monitor, state) do
    {:links, links} = Process.info(self(), :links)

    if links == [] do
      {:close, state}
    else
      Process.send_after(self(), :monitor, 1000)
      {:ok, state}
    end
  end

  def handle_text_message(msg, state) do
    GenServer.cast(state.callback_pid, {:chat_received, msg})
    {:ok, state}
  end
end
