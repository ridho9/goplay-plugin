defmodule GoplayPluginWeb.PageController do
  use GoplayPluginWeb, :controller

  def index(conn, _params) do
    conn |> redirect(to: "/tools") |> halt()
    # render(conn, "index.html")
  end
end
