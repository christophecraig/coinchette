defmodule CoinchetteWeb.Auth do
  @moduledoc """
  Authentication plugs for session management and user authentication.
  """

  import Plug.Conn
  import Phoenix.Controller
  alias Coinchette.Accounts

  @doc """
  Fetches the current user from the session and assigns it to the connection.
  """
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user!(user_id)
    assign(conn, :current_user, user)
  end

  @doc """
  Used for routes that require authentication.
  Redirects to login if no user is found.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/login")
      |> halt()
    end
  end

  @doc """
  Used for routes that require guest access (login, register).
  Redirects to lobby if user is already logged in.
  """
  def redirect_if_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: "/lobby")
      |> halt()
    else
      conn
    end
  end

  @doc """
  Logs in a user by storing their ID in the session.
  """
  def log_in_user(conn, user) do
    conn
    |> put_session(:user_id, user.id)
    |> put_flash(:info, "Welcome back, #{user.username}!")
    |> configure_session(renew: true)
  end

  @doc """
  Logs out a user by clearing the session.
  """
  def log_out_user(conn) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Logged out successfully.")
  end

  @doc """
  Used in LiveViews to assign current_user from session.
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    socket =
      case session["user_id"] do
        nil ->
          Phoenix.Component.assign(socket, :current_user, nil)

        user_id ->
          user = Accounts.get_user!(user_id)
          Phoenix.Component.assign(socket, :current_user, user)
      end

    {:cont, socket}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket =
      case session["user_id"] do
        nil ->
          socket
          |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
          |> Phoenix.LiveView.redirect(to: "/login")

        user_id ->
          user = Accounts.get_user!(user_id)
          Phoenix.Component.assign(socket, :current_user, user)
      end

    {:cont, socket}
  end
end
