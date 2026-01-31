defmodule Coinchette.Games.ScoreIntegrationTest do
  use ExUnit.Case, async: true

  alias Coinchette.Games.Game
  alias Coinchette.Bots

  describe "Score integration in full game" do
    test "game tracks scores after each trick" do
      # Given: A new game
      game =
        Game.new(:hearts)
        |> Game.deal_cards()

      # When: Play the first trick
      {:ok, game_after_trick1} = play_complete_trick(game)

      # Then: Scores are calculated
      assert game_after_trick1.scores[0] + game_after_trick1.scores[1] > 0
      assert is_integer(game_after_trick1.scores[0])
      assert is_integer(game_after_trick1.scores[1])
    end

    test "total points equal 162 at end of game (or 182 with Belote/Rebelote)" do
      # Given: A new game
      game =
        Game.new(:spades)
        |> Game.deal_cards()

      # When: Play complete game (8 tricks)
      final_game = play_full_game(game)

      # Then: Total points = 162 (with dix de der) or 182 (with Belote/Rebelote)
      total = final_game.scores[0] + final_game.scores[1]

      expected_total =
        if final_game.belote_rebelote do
          182  # 162 + 20 for Belote/Rebelote
        else
          162
        end

      assert total == expected_total
    end

    test "dix de der is added to last trick winner" do
      # Given: A new game
      game =
        Game.new(:diamonds)
        |> Game.deal_cards()

      # When: Play until 7 tricks
      game_before_last = play_n_tricks(game, 7)

      # Play last trick
      {:ok, final_game} = play_complete_trick(game_before_last)

      # Then: One team should have +10 points from dix de der
      # (Final score should be 162 total, or 182 with Belote/Rebelote)
      expected_total =
        if final_game.belote_rebelote do
          182  # 162 + 20 for Belote/Rebelote
        else
          162
        end

      assert final_game.scores[0] + final_game.scores[1] == expected_total

      # The game should be over
      assert Game.game_over?(final_game)
    end

    test "winner is determined by points, not trick count" do
      # Given: A complete game
      game =
        Game.new(:clubs)
        |> Game.deal_cards()

      # When: Play complete game
      final_game = play_full_game(game)

      # Then: Winner has most points (or equal in rare case of 81-81)
      winner = Game.winner(final_game)
      loser = if winner == 0, do: 1, else: 0

      assert final_game.scores[winner] >= final_game.scores[loser]
    end

    test "scores update progressively during game" do
      # Given: A new game
      game =
        Game.new(:hearts)
        |> Game.deal_cards()

      # When: Play tricks one by one
      {:ok, after_1} = play_complete_trick(game)
      {:ok, after_2} = play_complete_trick(after_1)
      {:ok, after_3} = play_complete_trick(after_2)

      # Then: Scores increase progressively
      score_1 = after_1.scores[0] + after_1.scores[1]
      score_2 = after_2.scores[0] + after_2.scores[1]
      score_3 = after_3.scores[0] + after_3.scores[1]

      assert score_1 > 0
      assert score_2 > score_1
      assert score_3 > score_2
    end
  end

  # Helper: Play one complete trick (4 cards)
  defp play_complete_trick(game) do
    with {:ok, g1} <- Game.play_bot_turn(game, Bots.Basic),
         {:ok, g2} <- Game.play_bot_turn(g1, Bots.Basic),
         {:ok, g3} <- Game.play_bot_turn(g2, Bots.Basic),
         {:ok, g4} <- Game.play_bot_turn(g3, Bots.Basic) do
      {:ok, g4}
    end
  end

  # Helper: Play N tricks
  defp play_n_tricks(game, n) do
    Enum.reduce(1..n, game, fn _i, g ->
      case play_complete_trick(g) do
        {:ok, updated} -> updated
        _ -> g
      end
    end)
  end

  # Helper: Play full game (8 tricks = 32 cards)
  defp play_full_game(game) do
    play_n_tricks(game, 8)
  end
end
