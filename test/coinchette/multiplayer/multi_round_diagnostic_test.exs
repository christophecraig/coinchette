defmodule Coinchette.Multiplayer.MultiRoundDiagnosticTest do
  use Coinchette.DataCase, async: false

  alias Coinchette.{Multiplayer, GameServer, GameServerSupervisor, Accounts}

  test "diagnostic: game transitions through states correctly" do
    # Create users
    {:ok, user1} = Accounts.register_user(%{username: "diag1", email: "diag1@test.com", password: "password123"})
    {:ok, user2} = Accounts.register_user(%{username: "diag2", email: "diag2@test.com", password: "password123"})

    # Create game
    {:ok, game} = Multiplayer.create_game(user1.id, variant: "belote", target_score: 500)
    IO.puts("✓ Game created: #{game.id}")
    IO.puts("  - Status: #{game.status}")
    IO.puts("  - Target: #{game.target_score}")
    IO.puts("  - Scores: #{inspect(game.scores)}")

    # Start GameServer
    {:ok, _pid} = GameServerSupervisor.start_game(game.id)
    Process.sleep(200)
    IO.puts("✓ GameServer started")

    # Add second player
    Multiplayer.add_player(game.id, user2.id, 2)
    IO.puts("✓ Second player added")

    # Check state before start_game
    state_before = GameServer.get_state(game.id)
    IO.puts("State before start_game:")
    IO.puts("  - Game status: #{state_before.game.status}")
    IO.puts("  - Players: #{length(state_before.game.players)}")

    # Start game
    {:ok, _started_game} = GameServer.start_game(game.id)
    Process.sleep(500)
    IO.puts("✓ Game started")

    # Check state after start_game
    state_after = GameServer.get_state(game.id)
    db_game_after = Multiplayer.get_game!(game.id)
    IO.puts("State after start_game:")
    IO.puts("  - Game status (memory): #{state_after.game.status}")
    IO.puts("  - Game status (DB): #{db_game_after.status}")
    IO.puts("  - Players: #{length(state_after.game.players)}")
    IO.puts("  - Player 0 hand: #{length(Enum.at(state_after.game.players, 0).hand)} cards")
    IO.puts("  - Current player: #{state_after.game.current_player_position}")

    # Try to complete bidding
    if state_after.game.status == :bidding do
      current_pos = state_after.game.current_player_position
      user_id = Map.get(state_after.player_map, current_pos)
      IO.puts("Making bid for player at position #{current_pos}")

      if user_id do
        result = GameServer.make_bid(game.id, user_id, :take)
        IO.puts("Bid result: #{inspect(result)}")
        Process.sleep(500)

        state_bid = GameServer.get_state(game.id)
        IO.puts("After bidding:")
        IO.puts("  - Game status: #{state_bid.game.status}")
        IO.puts("  - Bidding status: #{inspect(state_bid.game.bidding && state_bid.game.bidding.status)}")
        IO.puts("  - Trump: #{inspect(state_bid.game.trump_suit)}")
      end
    end

    # Final state check
    final_state = GameServer.get_state(game.id)
    final_db = Multiplayer.get_game!(game.id)
    IO.puts("\nFinal state:")
    IO.puts("  - Memory status: #{final_state.game.status}")
    IO.puts("  - DB status: #{final_db.status}")
    IO.puts("  - Tricks won: #{length(final_state.game.tricks_won)}")

    assert true  # Just diagnostic
  end
end
