defmodule Coinchette.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Coinchette.Accounts` context.
  """

  @doc """
  Generate a unique user email.
  """
  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"

  @doc """
  Generate a unique user username.
  """
  def unique_user_username, do: "user#{System.unique_integer([:positive])}"

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: unique_user_email(),
        username: unique_user_username(),
        password: "password123"
      })
      |> Coinchette.Accounts.register_user()

    user
  end

  @doc """
  Generate a user and return with plaintext password for testing.
  """
  def user_with_password_fixture(attrs \\ %{}) do
    password = attrs[:password] || "password123"
    user = user_fixture(attrs)
    {user, password}
  end
end
