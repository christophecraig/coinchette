defmodule Coinchette.AccountsTest do
  use Coinchette.DataCase

  alias Coinchette.Accounts
  alias Coinchette.Accounts.User

  describe "users" do
    @valid_attrs %{
      email: "user@example.com",
      username: "testuser",
      password: "password123",
      password_confirmation: "password123"
    }

    @invalid_attrs %{email: nil, username: nil, password: nil}

    test "register_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Accounts.register_user(@valid_attrs)
      assert user.email == "user@example.com"
      assert user.username == "testuser"
      assert user.hashed_password != nil
      assert user.hashed_password != "password123"
    end

    test "register_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.register_user(@invalid_attrs)
    end

    test "register_user/1 requires unique email" do
      assert {:ok, _user} = Accounts.register_user(@valid_attrs)

      assert {:error, changeset} =
               Accounts.register_user(%{@valid_attrs | username: "different"})

      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "register_user/1 requires unique username" do
      assert {:ok, _user} = Accounts.register_user(@valid_attrs)

      assert {:error, changeset} =
               Accounts.register_user(%{@valid_attrs | email: "different@example.com"})

      assert %{username: ["has already been taken"]} = errors_on(changeset)
    end

    test "register_user/1 validates password length" do
      assert {:error, changeset} =
               Accounts.register_user(%{@valid_attrs | password: "short", password_confirmation: "short"})

      assert %{password: ["should be at least 8 character(s)"]} = errors_on(changeset)
    end

    test "register_user/1 validates password confirmation" do
      assert {:error, changeset} =
               Accounts.register_user(%{@valid_attrs | password_confirmation: "different"})

      assert %{password_confirmation: ["passwords do not match"]} = errors_on(changeset)
    end

    test "get_user_by_email_and_password/2 with valid credentials returns user" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      assert {:ok, returned_user} = Accounts.get_user_by_email_and_password(user.email, "password123")
      assert returned_user.id == user.id
    end

    test "get_user_by_email_and_password/2 with invalid password returns error" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      assert {:error, :unauthorized} = Accounts.get_user_by_email_and_password(user.email, "wrongpassword")
    end

    test "get_user_by_email_and_password/2 with invalid email returns error" do
      assert {:error, :unauthorized} = Accounts.get_user_by_email_and_password("invalid@example.com", "password")
    end

    test "get_user!/1 returns the user with given id" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      assert %User{} = returned_user = Accounts.get_user!(user.id)
      assert returned_user.id == user.id
    end
  end
end
