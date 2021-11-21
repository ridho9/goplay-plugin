defmodule GoplayPluginWeb.Tools.ChatAppLive do
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
          assign(socket, host: host, slug: slug, event: event, page_title: event.title)

        {:error, err} ->
          put_flash(socket, :error, err)
          |> assign(page_title: "Chat")
      end

    {:ok, socket}
  end
end
