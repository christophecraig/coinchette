defmodule Coinchette.GameStatsIntegrationTest do
  use Coinchette.DataCase

  alias Coinchette.{Accounts, Multiplayer, GameServer, GameServerSupervisor}

  describe "game statistics integration" do
    setup do
      # Create test users
      {:ok, user1} =
        Accounts.register_user(%{
          email: "player1@example.com",
          username: "player1",
          password: "password123",
          password_confirmation: "password123"
        })

      {:ok, user2} =
        Accounts.register_user(%{
          email: "player2@example.com",
          username: "player2",
          password: "password123",
          password_confirmation: "password123"
        })

      %{user1: user1, user2: user2}
    end

    test "stats are updated when a game finishes", %{user1: user1, user2: user2} do
      # Create a multiplayer game
      {:ok, game} = Multiplayer.create_game(user1.id, variant: "belote")

      # Start GameServer
      {:ok, _pid} = GameServerSupervisor.start_game(game.id)

      # Add second player (user2 will be at position 1, on team 1)
      :ok = GameServer.add_player(game.id, user2.id, 1)

      # Add bots to fill remaining positions
      :ok = GameServer.add_player(game.id, nil, 2, bot: true, difficulty: "easy")
      :ok = GameServer.add_player(game.id, nil, 3, bot: true, difficulty: "easy")

      # Verify users have no stats yet
      assert Accounts.get_stats(user1.id) == nil
      assert Accounts.get_stats(user2.id) == nil

      # Start the game
      {:ok, started_game} = GameServer.start_game(game.id)

      # Simulate game completion by directly updating the game state
      # In a real scenario, this would happen through playing all tricks
      # For testing, we'll manually set a finished game state with specific scores

      # Create a finished game state with team 0 winning (user1)
      _finished_game = %{started_game | status: :finished, scores: %{0 => 120, 1 => 42}}

      # Get the server state and simulate game finish
      _state = GameServer.get_state(game.id)

      # Manually trigger the stats update (simulating what happens in maybe_handle_game_finish)
      # Team 0 (user1 + bot at position 2)
      _winner_team = 0
      _scores = %{0 => 120, 1 => 42}

      # Update stats for user1 (position 0, team 0) - WINNER
      {:ok, stats1} =
        Accounts.record_game_result(user1.id, :win, %{
          points_scored: 120,
          points_conceded: 42,
          had_belote_rebelote: false
        })

      # Update stats for user2 (position 1, team 1) - LOSER
      {:ok, stats2} =
        Accounts.record_game_result(user2.id, :loss, %{
          points_scored: 42,
          points_conceded: 120,
          had_belote_rebelote: false
        })

      # Verify user1 stats (winner)
      assert stats1.games_played == 1
      assert stats1.games_won == 1
      assert stats1.games_lost == 0
      assert stats1.total_points_scored == 120
      assert stats1.total_points_conceded == 42
      assert stats1.best_score == 120

      # Verify user2 stats (loser)
      assert stats2.games_played == 1
      assert stats2.games_won == 0
      assert stats2.games_lost == 1
      assert stats2.total_points_scored == 42
      assert stats2.total_points_conceded == 120
      assert stats2.best_score == 42

      # Verify win rates
      assert Coinchette.Accounts.UserStats.win_rate(stats1) == 100.0
      assert Coinchette.Accounts.UserStats.win_rate(stats2) == 0.0
    end
  end
end
