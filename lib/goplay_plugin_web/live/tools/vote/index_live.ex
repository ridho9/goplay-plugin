defmodule GoplayPluginWeb.Tools.Vote.IndexLive do
  use GoplayPluginWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Vote")}
  end

  def handle_event("run", %{"input" => %{"event_url" => url}}, socket) do
    uri = URI.parse(url)
    host = uri.host

    case String.split(uri.path, "/") do
      ["", "live", slug] when slug != "" ->
        case GoplayPlugin.API.Goplay.event_details(host, slug) do
          {:ok, _} ->
            redirect_url =
              Routes.live_path(socket, GoplayPluginWeb.Tools.Vote.AppLive,
                slug: slug,
                host: host
              )

            socket = push_redirect(socket, to: redirect_url)
            {:noreply, socket}

          {:error, err} ->
            socket = put_flash(socket, :error, err)
            {:noreply, socket}
        end

      _ ->
        socket = put_flash(socket, :error, "Invalid URL")
        {:noreply, socket}
    end
  end
end
