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
               Accounts.register_user(%{
                 @valid_attrs
                 | password: "short",
                   password_confirmation: "short"
               })

      assert %{password: ["should be at least 8 character(s)"]} = errors_on(changeset)
    end

    test "register_user/1 validates password confirmation" do
      assert {:error, changeset} =
               Accounts.register_user(%{@valid_attrs | password_confirmation: "different"})

      assert %{password_confirmation: ["passwords do not match"]} = errors_on(changeset)
    end

    test "get_user_by_email_and_password/2 with valid credentials returns user" do
      {:ok, user} = Accounts.register_user(@valid_attrs)

      assert {:ok, returned_user} =
               Accounts.get_user_by_email_and_password(user.email, "password123")

      assert returned_user.id == user.id
    end

    test "get_user_by_email_and_password/2 with invalid password returns error" do
      {:ok, user} = Accounts.register_user(@valid_attrs)

      assert {:error, :unauthorized} =
               Accounts.get_user_by_email_and_password(user.email, "wrongpassword")
    end

    test "get_user_by_email_and_password/2 with invalid email returns error" do
      assert {:error, :unauthorized} =
               Accounts.get_user_by_email_and_password("invalid@example.com", "password")
    end

    test "get_user!/1 returns the user with given id" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      assert %User{} = returned_user = Accounts.get_user!(user.id)
      assert returned_user.id == user.id
    end
  end

  describe "ELO calculation" do
    test "calculate_elo/3 win against equal opponent gives ~16 points" do
      new_elo = Accounts.calculate_elo(1000, 1000, :win)
      assert new_elo == 1016
    end

    test "calculate_elo/3 loss against equal opponent loses ~16 points" do
      new_elo = Accounts.calculate_elo(1000, 1000, :loss)
      assert new_elo == 984
    end

    test "calculate_elo/3 win against stronger opponent gives more points" do
      new_elo = Accounts.calculate_elo(1000, 1400, :win)
      assert new_elo > 1016
    end

    test "calculate_elo/3 loss against weaker opponent loses more points" do
      new_elo = Accounts.calculate_elo(1400, 1000, :loss)
      assert new_elo < 1384
    end
  end

  describe "record_game_result with new fields" do
    setup do
      {:ok, user} = Accounts.register_user(%{
        email: "stats@example.com",
        username: "statsuser",
        password: "password123",
        password_confirmation: "password123"
      })
      %{user: user}
    end

    test "updates win streak on consecutive wins", %{user: user} do
      game_data = %{points_scored: 100, points_conceded: 50, had_belote_rebelote: false}

      {:ok, stats} = Accounts.record_game_result(user.id, :win, game_data)
      assert stats.current_win_streak == 1
      assert stats.best_win_streak == 1

      {:ok, stats} = Accounts.record_game_result(user.id, :win, game_data)
      assert stats.current_win_streak == 2
      assert stats.best_win_streak == 2
    end

    test "resets win streak on loss, keeps best", %{user: user} do
      game_data = %{points_scored: 100, points_conceded: 50, had_belote_rebelote: false}

      {:ok, _} = Accounts.record_game_result(user.id, :win, game_data)
      {:ok, _} = Accounts.record_game_result(user.id, :win, game_data)
      {:ok, stats} = Accounts.record_game_result(user.id, :loss, game_data)

      assert stats.current_win_streak == 0
      assert stats.best_win_streak == 2
    end

    test "tracks team stats", %{user: user} do
      game_data = %{points_scored: 100, points_conceded: 50, had_belote_rebelote: false, team: 0}
      {:ok, stats} = Accounts.record_game_result(user.id, :win, game_data)
      assert stats.games_as_team0 == 1
      assert stats.wins_as_team0 == 1

      game_data = %{points_scored: 50, points_conceded: 100, had_belote_rebelote: false, team: 1}
      {:ok, stats} = Accounts.record_game_result(user.id, :loss, game_data)
      assert stats.games_as_team1 == 1
      assert stats.wins_as_team1 == 0
    end

    test "updates ELO for multiplayer games", %{user: user} do
      game_data = %{
        points_scored: 100,
        points_conceded: 50,
        had_belote_rebelote: false,
        is_multiplayer: true,
        opponent_elo: 1000
      }

      {:ok, stats} = Accounts.record_game_result(user.id, :win, game_data)
      assert stats.elo_rating == 1016
    end

    test "does not update ELO for solo games", %{user: user} do
      game_data = %{points_scored: 100, points_conceded: 50, had_belote_rebelote: false}
      {:ok, stats} = Accounts.record_game_result(user.id, :win, game_data)
      assert stats.elo_rating == 1000
    end
  end
end
