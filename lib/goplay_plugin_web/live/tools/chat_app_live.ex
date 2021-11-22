defmodule GoplayPluginWeb.Tools.ChatAppLive do
  alias GoplayPlugin.WS.Vanguard
  use GoplayPluginWeb, :live_view

  def mount(
        %{"host" => host, "slug" => slug},
        _session,
        socket
      ) do
    socket =
      case GoplayPlugin.API.Goplay.event_details(host, slug) do
        {:ok, event} ->
          event = %{title: event["title"], status: event["status"], guard_url: event["guard_url"]}

          {:ok, vg} = Vanguard.start_link(event.guard_url, self())
          GenServer.cast(self(), :chat_fetch)

          assign(socket,
            host: host,
            slug: slug,
            event: event,
            page_title: event.title,
            vanguard: vg,
            chat: %{}
          )

        {:error, err} ->
          put_flash(socket, :error, err)
          |> assign(page_title: "Chat")
      end

    {:ok, socket}
  end

  def handle_cast(:chat_fetch, %{assigns: %{vanguard: vg}} = socket) do
    Vanguard.join_chat_room(vg)
    {:noreply, socket}
  end

  def handle_cast({:chat_fetched, chat}, %{assigns: %{vanguard: vg}} = socket) do
    socket = assign(socket, chat: chat)
    GenServer.stop(vg)
    {:noreply, socket}
  end
end
