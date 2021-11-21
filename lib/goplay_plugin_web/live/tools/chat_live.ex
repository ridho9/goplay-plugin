defmodule GoplayPluginWeb.Tools.ChatLive do
  use GoplayPluginWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Chat")}
  end

  def handle_event("run", %{"input" => %{"event_slug" => slug}}, socket) do
    host = "goplay.co.id"

    case GoplayPlugin.API.Goplay.event_details(host, slug) do
      {:ok, _} ->
        redirect_url =
          Routes.live_path(socket, GoplayPluginWeb.Tools.ChatAppLive, slug: slug, host: host)

        socket = push_redirect(socket, to: redirect_url)
        {:noreply, socket}

      {:error, err} ->
        socket = put_flash(socket, :error, err)
        {:noreply, socket}
    end
  end
end
