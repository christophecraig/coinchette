defmodule Coinchette.Multiplayer.MultiRoundTest do
  use Coinchette.DataCase, async: false

  alias Coinchette.{Multiplayer, GameServer, GameServerSupervisor, Accounts}

  describe "multi-round gameplay" do
    setup do
      # Create test users - all 4 players are human for easier testing
      {:ok, user1} = Accounts.register_user(%{username: "player1", email: "p1@test.com", password: "password123"})
      {:ok, user2} = Accounts.register_user(%{username: "player2", email: "p2@test.com", password: "password123"})
      {:ok, user3} = Accounts.register_user(%{username: "player3", email: "p3@test.com", password: "password123"})
      {:ok, user4} = Accounts.register_user(%{username: "player4", email: "p4@test.com", password: "password123"})

      # Create game with 500 point target for faster testing
      {:ok, game} = Multiplayer.create_game(user1.id, variant: "belote", target_score: 500)

      # Start GameServer
      {:ok, _pid} = GameServerSupervisor.start_game(game.id)
      on_exit(fn -> GameServerSupervisor.stop_game(game.id) end)

      # Add all players
      Multiplayer.add_player(game.id, user2.id, 1)
      Multiplayer.add_player(game.id, user3.id, 2)
      Multiplayer.add_player(game.id, user4.id, 3)

      # Start game (all positions filled with humans, no bots)
      {:ok, _started_game} = GameServer.start_game(game.id)

      %{game_id: game.id, user1: user1, user2: user2, user3: user3, user4: user4}
    end

    test "cumulative scores start at 0 for both teams", %{game_id: game_id} do
      db_game = Multiplayer.get_game!(game_id)

      assert db_game.scores == %{"0" => 0, "1" => 0}
      assert db_game.target_score == 500
      assert db_game.round_number == 1
    end

    test "after completing one hand, cumulative scores are updated", %{game_id: game_id} do
      # Play a complete hand (32 cards)
      play_complete_hand(game_id)

      # Wait for async processing
      Process.sleep(1000)

      # Reload game from DB
      db_game = Multiplayer.get_game!(game_id)

      # Cumulative scores should be updated (sum = 162, or 182 with Belote/Rebelote)
      # Scores might have string or integer keys depending on DB/Ecto
      team_0_score = get_score(db_game.scores, 0)
      team_1_score = get_score(db_game.scores, 1)

      total = team_0_score + team_1_score
      assert total in [162, 182], "Expected total 162 or 182 (with Belote/Rebelote), got #{total}"
      assert team_0_score > 0 or team_1_score > 0
    end

    test "if target score not reached, new round starts automatically", %{game_id: game_id} do
      # Play first hand
      play_complete_hand(game_id)

      # Wait a bit for round processing
      Process.sleep(1500)

      # Reload game
      db_game = Multiplayer.get_game!(game_id)
      state = GameServer.get_state(game_id)

      # Cumulative scores should be > 0 but < 500
      team_0_score = get_score(db_game.scores, 0)
      team_1_score = get_score(db_game.scores, 1)

      assert team_0_score < 500
      assert team_1_score < 500

      # Should be in round 2 now
      assert db_game.round_number == 2

      # Game should still be playing
      assert db_game.status == "playing"

      # New hand should be dealt (players should have 5 cards each after bidding)
      assert length(state.game.players) == 4
      # During bidding phase, players have 5 cards
      assert Enum.all?(state.game.players, fn p -> length(p.hand) == 5 end)
    end

    test "dealer position rotates between rounds", %{game_id: game_id} do
      state1 = GameServer.get_state(game_id)
      initial_dealer = state1.game.dealer_position

      # Complete first hand
      play_complete_hand(game_id)

      # Wait for new round
      Process.sleep(500)

      state2 = GameServer.get_state(game_id)
      new_dealer = state2.game.dealer_position

      # Dealer should have rotated clockwise
      assert new_dealer == rem(initial_dealer + 1, 4)
    end

    test "when target score is reached, game finishes completely", %{game_id: game_id} do
      # Play multiple hands until target reached
      # With 500 point target, need approximately 3-4 hands
      max_rounds = 10

      Enum.reduce_while(1..max_rounds, nil, fn _round, _acc ->
        db_game = Multiplayer.get_game!(game_id)

        if db_game.status == "finished" do
          {:halt, :finished}
        else
          play_complete_hand(game_id)
          Process.sleep(1500)
          {:cont, nil}
        end
      end)

      # Game should now be finished
      db_game = Multiplayer.get_game!(game_id)

      assert db_game.status == "finished"
      assert db_game.winner_team in [0, 1]
      assert db_game.finished_at != nil

      # Winner should have >= target_score
      winner_score = get_score(db_game.scores, db_game.winner_team)
      assert winner_score >= 500
    end

    test "round_number increments with each new round", %{game_id: game_id} do
      # Play first hand
      play_complete_hand(game_id)
      Process.sleep(500)

      db_game_r2 = Multiplayer.get_game!(game_id)
      assert db_game_r2.round_number == 2

      # Play second hand (if game not finished)
      if db_game_r2.status == "playing" do
        play_complete_hand(game_id)
        Process.sleep(500)

        db_game_r3 = Multiplayer.get_game!(game_id)
        assert db_game_r3.round_number == 3
      end
    end

    test "cumulative scores persist across rounds", %{game_id: game_id} do
      # Play first hand
      play_complete_hand(game_id)
      Process.sleep(1500)

      db_game_r1 = Multiplayer.get_game!(game_id)
      round_1_team_0 = get_score(db_game_r1.scores, 0)
      round_1_team_1 = get_score(db_game_r1.scores, 1)

      # Play second hand
      if db_game_r1.status == "playing" do
        play_complete_hand(game_id)
        Process.sleep(1500)

        db_game_r2 = Multiplayer.get_game!(game_id)
        round_2_team_0 = get_score(db_game_r2.scores, 0)
        round_2_team_1 = get_score(db_game_r2.scores, 1)

        # Cumulative scores should increase
        assert round_2_team_0 >= round_1_team_0
        assert round_2_team_1 >= round_1_team_1

        # Total should be ~324 (162 * 2) but can be higher with belote/rebelote/announcements
        total = round_2_team_0 + round_2_team_1
        # At minimum 324 (2 x 162), at most ~400 with bonuses
        assert total >= 300 and total <= 450
      end
    end
  end

  describe "game creation with target_score" do
    test "creates game with default target_score of 1000" do
      {:ok, user} = Accounts.register_user(%{username: "test", email: "test@test.com", password: "password123"})
      {:ok, game} = Multiplayer.create_game(user.id, variant: "belote")

      assert game.target_score == 1000
      assert game.round_number == 1
      assert game.scores == %{"0" => 0, "1" => 0}
    end

    test "creates game with custom target_score of 500" do
      {:ok, user} = Accounts.register_user(%{username: "test2", email: "test2@test.com", password: "password123"})
      {:ok, game} = Multiplayer.create_game(user.id, variant: "belote", target_score: 500)

      assert game.target_score == 500
    end

    test "rejects invalid target_score" do
      {:ok, user} = Accounts.register_user(%{username: "test3", email: "test3@test.com", password: "password123"})

      assert {:error, changeset} = Multiplayer.create_game(user.id, variant: "belote", target_score: 750)
      assert "is invalid" in errors_on(changeset).target_score
    end
  end

  # Helper function to play a complete hand
  defp play_complete_hand(game_id) do
    # Complete bidding phase first
    complete_bidding(game_id)

    # Play all 32 cards
    Enum.each(1..32, fn _i ->
      state = GameServer.get_state(game_id)

      if state.game.status == :playing do
        current_pos = state.game.current_player_position
        current_player = Enum.at(state.game.players, current_pos)

        # Find a valid card to play
        valid_cards = Coinchette.Games.Rules.valid_cards(
          current_player,
          state.game.current_trick,
          state.game.trump_suit,
          current_pos
        )

        if length(valid_cards) > 0 do
          card = hd(valid_cards)
          user_id = Map.get(state.player_map, current_pos)

          if user_id do
            GameServer.play_card(game_id, user_id, card)
            Process.sleep(50)
          end
        end
      end
    end)
  end

  defp complete_bidding(game_id) do
    # Wait for bidding to be ready
    Process.sleep(200)

    # Keep making bids until bidding is complete
    # Max 8 bids (2 rounds x 4 players)
    Enum.reduce_while(1..8, nil, fn _i, _acc ->
      state = GameServer.get_state(game_id)

      cond do
        state.game.status == :bidding_completed or state.game.status == :playing ->
          {:halt, :done}

        state.game.status == :bidding and state.game.bidding ->
          current_bidder_pos = state.game.bidding.current_bidder
          user_id = Map.get(state.player_map, current_bidder_pos)
          taker = state.game.bidding.taker

          if user_id do
            # First bidder in round 1 takes, all others pass
            bid_action = if is_nil(taker), do: :take, else: :pass
            GameServer.make_bid(game_id, user_id, bid_action)
            Process.sleep(150)
            {:cont, nil}
          else
            {:halt, :no_user}
          end

        true ->
          {:halt, :done}
      end
    end)

    # Wait for cards to be dealt after bidding completes
    Process.sleep(300)
  end

  # Helper to get score from map with either string or integer keys
  defp get_score(scores, team) when is_map(scores) do
    Map.get(scores, team) || Map.get(scores, Integer.to_string(team)) || Map.get(scores, to_string(team)) || 0
  end

  defp get_score(_, _), do: 0
end
