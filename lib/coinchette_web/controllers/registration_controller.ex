defmodule CoinchetteWeb.RegistrationController do
  use CoinchetteWeb, :controller

  alias Coinchette.Accounts
  alias Coinchette.Accounts.User

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, :new, changeset: changeset, page_title: "Register")
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Account created successfully!")
        |> redirect(to: ~p"/login")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, page_title: "Register")
    end
  end
end
