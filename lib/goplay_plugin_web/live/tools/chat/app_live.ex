defmodule GoplayPluginWeb.Tools.Chat.AppLive do
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
        page_title: "Chat",
        vanguard: nil,
        chat_ws: nil,
        chat_setting: %{},
        chats: [],
        update_counter: 0,
        switch: %{
          "message" => true,
          "gift" => true
        }
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
            page_title: event.title,
            vanguard: nil,
            chat_ws: nil,
            chat_setting: %{},
            chats: [],
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
    Logger.info("chatapp started vg #{inspect(vg)}")
    GenServer.cast(self(), :chat_fetch)
    {:noreply, assign(socket, vanguard: vg)}
  end

  def handle_cast(:chat_fetch, %{assigns: %{vanguard: vg}} = socket) do
    Vanguard.join_chat_room(vg)
    {:noreply, socket}
  end

  def handle_cast({:chat_fetched, chat}, %{assigns: %{vanguard: vg, host: host}} = socket) do
    chat_url =
      if host == "goplay.co.id" do
        "wss://gschat.goplay.co.id/chat"
      else
        "wss://g-gschat.goplay.co.id/chat"
      end

    chat = Map.put(chat, :url, chat_url)

    socket = assign(socket, chat_setting: chat, vanguard: nil)
    GenServer.stop(vg)
    GenServer.cast(self(), :chat_connect)
    {:noreply, socket}
  end

  def handle_cast(:chat_connect, %{assigns: %{chat_setting: setting}} = socket) do
    {:ok, chat_ws} = Chat.start_link(setting.url, self(), setting)
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
        %{"ct" => 20, "id" => id, "msg" => msg, "frm" => frm},
        socket
      ) do
    chat = %{
      id: "chat-#{id}",
      type: "message",
      msg: msg,
      from: frm,
      show: socket.assigns.switch["message"]
    }

    {:noreply,
     update(socket, :chats, fn chats ->
       chats ++ [chat]
     end)}
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
    chat = %{
      id: "gift-#{id}",
      type: "gift",
      msg: msg,
      from: frm,
      icon: icon,
      price: price,
      title: title
    }

    {:noreply,
     update(socket, :chats, fn chats ->
       chats ++ [chat]
     end)}
  end

  def handle_chat(_item, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle-switch", %{"key" => key}, socket) do
    socket =
      update(socket, :switch, fn switch ->
        %{switch | key => !switch[key]}
      end)

    {:noreply, socket}
  end
end
