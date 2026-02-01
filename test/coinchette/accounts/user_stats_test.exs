defmodule Coinchette.Accounts.UserStatsTest do
  use Coinchette.DataCase

  alias Coinchette.Accounts
  alias Coinchette.Accounts.UserStats

  describe "user_stats" do
    setup do
      # Create a test user
      {:ok, user} = Accounts.register_user(%{
        email: "test@example.com",
        username: "testuser",
        password: "password123",
        password_confirmation: "password123"
      })

      %{user: user}
    end

    test "get_or_create_stats/1 creates stats for a new user", %{user: user} do
      assert {:ok, stats} = Accounts.get_or_create_stats(user.id)
      assert stats.user_id == user.id
      assert stats.games_played == 0
      assert stats.games_won == 0
      assert stats.games_lost == 0
      assert stats.total_points_scored == 0
      assert stats.total_points_conceded == 0
      assert stats.belote_rebelote_count == 0
      assert stats.best_score == 0
    end

    test "get_or_create_stats/1 returns existing stats", %{user: user} do
      {:ok, stats1} = Accounts.get_or_create_stats(user.id)
      {:ok, stats2} = Accounts.get_or_create_stats(user.id)

      assert stats1.id == stats2.id
    end

    test "record_game_result/3 updates stats for a win", %{user: user} do
      {:ok, _stats} = Accounts.get_or_create_stats(user.id)

      # Record a win with 120 points scored, 42 points conceded
      {:ok, updated_stats} = Accounts.record_game_result(user.id, :win, %{
        points_scored: 120,
        points_conceded: 42,
        had_belote_rebelote: true
      })

      assert updated_stats.games_played == 1
      assert updated_stats.games_won == 1
      assert updated_stats.games_lost == 0
      assert updated_stats.total_points_scored == 120
      assert updated_stats.total_points_conceded == 42
      assert updated_stats.belote_rebelote_count == 1
      assert updated_stats.best_score == 120
    end

    test "record_game_result/3 updates stats for a loss", %{user: user} do
      {:ok, _stats} = Accounts.get_or_create_stats(user.id)

      # Record a loss
      {:ok, updated_stats} = Accounts.record_game_result(user.id, :loss, %{
        points_scored: 42,
        points_conceded: 120,
        had_belote_rebelote: false
      })

      assert updated_stats.games_played == 1
      assert updated_stats.games_won == 0
      assert updated_stats.games_lost == 1
      assert updated_stats.total_points_scored == 42
      assert updated_stats.total_points_conceded == 120
      assert updated_stats.belote_rebelote_count == 0
      assert updated_stats.best_score == 42
    end

    test "record_game_result/3 updates best_score correctly", %{user: user} do
      {:ok, _stats} = Accounts.get_or_create_stats(user.id)

      # First game with 80 points
      {:ok, stats1} = Accounts.record_game_result(user.id, :win, %{
        points_scored: 80,
        points_conceded: 82,
        had_belote_rebelote: false
      })
      assert stats1.best_score == 80

      # Second game with 120 points (new best)
      {:ok, stats2} = Accounts.record_game_result(user.id, :win, %{
        points_scored: 120,
        points_conceded: 42,
        had_belote_rebelote: false
      })
      assert stats2.best_score == 120

      # Third game with 70 points (doesn't change best)
      {:ok, stats3} = Accounts.record_game_result(user.id, :loss, %{
        points_scored: 70,
        points_conceded: 92,
        had_belote_rebelote: false
      })
      assert stats3.best_score == 120
    end

    test "record_game_result/3 accumulates stats over multiple games", %{user: user} do
      {:ok, _stats} = Accounts.get_or_create_stats(user.id)

      # Game 1: Win
      {:ok, _} = Accounts.record_game_result(user.id, :win, %{
        points_scored: 100,
        points_conceded: 62,
        had_belote_rebelote: true
      })

      # Game 2: Win
      {:ok, _} = Accounts.record_game_result(user.id, :win, %{
        points_scored: 90,
        points_conceded: 72,
        had_belote_rebelote: false
      })

      # Game 3: Loss
      {:ok, final_stats} = Accounts.record_game_result(user.id, :loss, %{
        points_scored: 60,
        points_conceded: 102,
        had_belote_rebelote: true
      })

      assert final_stats.games_played == 3
      assert final_stats.games_won == 2
      assert final_stats.games_lost == 1
      assert final_stats.total_points_scored == 250
      assert final_stats.total_points_conceded == 236
      assert final_stats.belote_rebelote_count == 2
      assert final_stats.best_score == 100
    end

    test "get_stats/1 returns nil for user without stats" do
      # Create a user without stats
      {:ok, user2} = Accounts.register_user(%{
        email: "test2@example.com",
        username: "testuser2",
        password: "password123",
        password_confirmation: "password123"
      })

      assert Accounts.get_stats(user2.id) == nil
    end

    test "get_stats/1 returns existing stats", %{user: user} do
      {:ok, created_stats} = Accounts.get_or_create_stats(user.id)

      fetched_stats = Accounts.get_stats(user.id)
      assert fetched_stats.id == created_stats.id
      assert fetched_stats.user_id == user.id
    end
  end
end
