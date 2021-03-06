defmodule GoplayPluginWeb.Router do
  use GoplayPluginWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {GoplayPluginWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :secured do
    plug :auth
  end

  scope "/", GoplayPluginWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/tools", GoplayPluginWeb.Tools do
    pipe_through :browser

    get "/", HomeController, :index

    scope "/chat", Chat do
      live "/", IndexLive
      live "/app", AppLive
    end

    scope "/vote", Vote do
      live "/", IndexLive
      live "/app", AppLive
    end
  end

  # Other scopes may use custom stacks.
  scope "/api", GoplayPluginWeb do
    pipe_through :api
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  # if Mix.env() in [:dev, :test] do

  import Phoenix.LiveDashboard.Router

  scope "/" do
    if Mix.env() not in [:dev, :test] do
      pipe_through :secured
    end

    pipe_through :browser
    live_dashboard "/dashboard", metrics: GoplayPluginWeb.Telemetry
  end

  # end

  defp auth(conn, opts) do
    password = Application.fetch_env!(:goplay_plugin, :dashboard_password)
    Plug.BasicAuth.basic_auth(conn, username: "admin", password: password)
  end
end
