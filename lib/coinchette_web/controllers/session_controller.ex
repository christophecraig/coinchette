defmodule CoinchetteWeb.SessionController do
  use CoinchetteWeb, :controller

  alias Coinchette.Accounts
  alias CoinchetteWeb.Auth

  def new(conn, _params) do
    render(conn, :new, page_title: "Log in")
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      {:ok, user} ->
        conn
        |> Auth.log_in_user(user)
        |> redirect(to: "/lobby")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> render(:new, page_title: "Log in")
    end
  end

  def delete(conn, _params) do
    conn
    |> Auth.log_out_user()
    |> redirect(to: "/")
  end
end
