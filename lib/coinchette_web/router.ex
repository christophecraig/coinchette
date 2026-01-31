defmodule CoinchetteWeb.Router do
  use CoinchetteWeb, :router

  import CoinchetteWeb.Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CoinchetteWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug CoinchetteWeb.Plugs.TestAuth
    plug :fetch_current_user
  end

  pipeline :require_auth do
    plug :require_authenticated_user
  end

  pipeline :redirect_if_auth do
    plug :redirect_if_authenticated
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CoinchetteWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/game", GameLive
  end

  # Authentication routes (guest only)
  scope "/", CoinchetteWeb do
    pipe_through [:browser, :redirect_if_auth]

    live "/register", RegistrationLive
    get "/login", SessionController, :new
    post "/login", SessionController, :create
  end

  # Authenticated routes
  scope "/", CoinchetteWeb do
    pipe_through [:browser, :require_auth]

    delete "/logout", SessionController, :delete
    live "/lobby", LobbyLive
    live "/game/:id/lobby", GameLobbyLive
    live "/game/:id/play", MultiplayerGameLive
    live "/game/:id/history", GameHistoryLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", CoinchetteWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:coinchette, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CoinchetteWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
