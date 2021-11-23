defmodule GoplayPluginWeb.Tools.HomeController do
  use GoplayPluginWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
