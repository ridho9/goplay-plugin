defmodule GoplayPlugin.WS.Vanguard do
  use WebSockex
  require Logger

  def start_link(url, callback_pid) do
    ssl_opts = [
      verify: :verify_none,
      versions: [:"tlsv1.1"],
      ciphers: :ssl.cipher_suites(:all, :"tlsv1.1")
    ]

    WebSockex.start_link(
      url,
      __MODULE__,
      %{callback_pid: callback_pid},
      ssl_options: ssl_opts
    )
  end

  def handle_connect(_conn, state) do
    Logger.info("vg connect")
    Process.send_after(self(), :monitor, 1000)
    {:ok, state}
  end

  def handle_disconnect(_, state) do
    Logger.info("vg disconnect")
    {:ok, state}
  end

  def join_chat_room(pid) do
    msg = %{
      "action_type" => "join_chat_room",
      "username" => "gptbot",
      "recon" => false
    }

    send_message(pid, msg)
  end

  def handle_frame({:text, msg}, state) do
    with {:ok, msg} <- Jason.decode(msg) do
      handle_text_message(msg, state)
    end
  end

  def handle_text_message(
        %{
          "action_type" => "join_chat_success",
          "recon" => recon,
          "room_id" => room_id,
          "session" => session,
          "token" => token,
          "username" => username
        },
        state
      ) do
    chat = %{
      recon: recon,
      room_id: room_id,
      session: session,
      token: token,
      username: username
    }

    Logger.info("vg joined chat")
    GenServer.cast(state.callback_pid, {:chat_fetched, chat})
    state = Map.put(state, :chat, chat)
    {:ok, state}
  end

  def handle_text_message(_msg, state) do
    {:ok, state}
  end

  defp send_message(pid, msg) do
    msg = Jason.encode!(msg)
    WebSockex.send_frame(pid, {:text, msg})
  end

  def handle_info(:monitor, state) do
    {:links, links} = Process.info(self(), :links)
    Logger.info("vg links #{inspect(links)}")

    if links == [] do
      {:close, state}
    else
      Process.send_after(self(), :monitor, 1000)
      {:ok, state}
    end
  end

  def terminate(reason, _state) do
    Logger.info("vg terminate #{reason}")
    exit(:normal)
  end
end
