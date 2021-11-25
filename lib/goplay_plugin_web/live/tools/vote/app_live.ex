defmodule GoplayPluginWeb.Tools.Vote.AppLive do
  use GoplayPluginWeb, :live_view
  require Logger

  alias GoplayPlugin.WS.Vanguard
  alias GoplayPlugin.WS.Chat

  def mount(
        %{"host" => host, "slug" => slug},
        _session,
        socket
      ) do
    socket =
      assign(socket,
        host: "",
        slug: "",
        event: %{},
        page_title: "Vote",
        vanguard: nil,
        chat_ws: nil,
        chat_setting: %{},
        vote_started: false,
        vote_options: [],
        voted_user: MapSet.new(),
        vote_answers: []
      )

    socket =
      case GoplayPlugin.API.Goplay.event_details(host, slug) do
        {:ok, event} ->
          event = %{title: event["title"], status: event["status"], guard_url: event["guard_url"]}

          if event.status != "finished" and connected?(socket) do
            GenServer.cast(self(), :connect_vg)
          end

          assign(socket,
            host: host,
            slug: slug,
            event: event,
            page_title: "#{event.title} - Vote",
            status: event.status
          )

        {:error, err} ->
          put_flash(socket, :error, err)
          |> assign(status: "invalid")
      end

    # {:ok, socket, temporary_assigns: [chats: []]}
    {:ok, socket}
  end

  def handle_cast(:connect_vg, %{assigns: %{event: event}} = socket) do
    {:ok, vg} = Vanguard.start_link(event.guard_url, self())
    Logger.info("votepp started vg #{inspect(vg)}")
    GenServer.cast(self(), :chat_fetch)
    {:noreply, assign(socket, vanguard: vg)}
  end

  def handle_cast(:chat_fetch, %{assigns: %{vanguard: vg}} = socket) do
    Vanguard.join_chat_room(vg)
    {:noreply, socket}
  end

  def handle_cast({:chat_fetched, chat}, %{assigns: %{vanguard: vg, host: host}} = socket) do
    chat =
      Map.put(chat, :event_host, host)
      |> Map.put(:recon, true)

    socket = assign(socket, chat_setting: chat, vanguard: nil)
    GenServer.stop(vg)
    GenServer.cast(self(), :chat_connect)
    {:noreply, socket}
  end

  def handle_cast(:chat_connect, %{assigns: %{chat_setting: setting}} = socket) do
    {:ok, chat_ws} = Chat.start_link(setting, self())
    socket = assign(socket, chat_ws: chat_ws)
    GenServer.cast(self(), :chat_join)
    {:noreply, socket}
  end

  def handle_cast(:chat_join, %{assigns: %{chat_ws: ws, chat_setting: setting}} = socket) do
    Chat.join(ws, setting)
    {:noreply, socket}
  end

  def handle_cast({:chat_received, received}, socket) do
    handle_chat(received, socket)
  end

  def handle_chat(
        %{"ct" => 20, "id" => id, "msg" => msg, "frm" => frm} = chat,
        socket
      ) do
    msg = String.trim(msg) |> String.split()

    with ["vote", option | _] <- msg,
         {option, _} <- Integer.parse(option),
         true <- socket.assigns.vote_started,
         true <- 0 < option && option <= length(socket.assigns.vote_options),
         # TODO: Fix line below to true <- for unique user voting
         true <- MapSet.member?(socket.assigns.voted_user, frm) do
      option = option - 1

      socket =
        update(socket, :voted_user, &MapSet.put(&1, frm))
        |> update(:vote_answers, &[option | &1])

      {:noreply, socket}
    else
      _ ->
        {:noreply, socket}
    end
  end

  def handle_chat(
        %{
          "ct" => 82,
          "id" => id,
          "message" => msg,
          "frm" => frm,
          "icon" => icon,
          "price" => price,
          "title_id" => title
        },
        socket
      ) do
    {:noreply, socket}
  end

  def handle_chat(_item, socket) do
    {:noreply, socket}
  end

  def handle_event("start-vote", _params, socket) do
    socket = assign(socket, vote_started: true, voted_users: MapSet.new(), vote_answers: [])
    {:noreply, socket}
  end

  def handle_event("stop-vote", _params, socket) do
    socket = assign(socket, vote_started: false)
    {:noreply, socket}
  end

  def handle_event("add-option", %{"form" => %{"name" => name}}, socket) do
    socket = update(socket, :vote_options, fn vote -> vote ++ [name] end)
    {:noreply, socket}
  end

  def handle_event("clear-option", _, socket) do
    socket = assign(socket, vote_options: [], vote_answers: [])
    {:noreply, socket}
  end

  def handle_event("delete-option", %{"idx" => idx}, socket) do
    socket =
      update(socket, :vote_options, fn vote ->
        List.delete_at(vote, String.to_integer(idx))
      end)
      |> assign(vote_answers: [])

    {:noreply, socket}
  end
end
