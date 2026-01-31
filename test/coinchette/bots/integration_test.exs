defmodule Coinchette.Bots.IntegrationTest do
  use ExUnit.Case, async: true

  alias Coinchette.Bots.Basic
  alias Coinchette.Games.Game

  describe "Bot integration with Game" do
    test "bot can play a complete trick in a real game" do
      # Given: A game with 4 players
      game =
        Game.new(:hearts)
        |> Game.deal_cards()

      # When: Bot plays 4 turns (one complete trick)
      {:ok, game_after_1} = Game.play_bot_turn(game, Basic)
      {:ok, game_after_2} = Game.play_bot_turn(game_after_1, Basic)
      {:ok, game_after_3} = Game.play_bot_turn(game_after_2, Basic)
      {:ok, game_after_4} = Game.play_bot_turn(game_after_3, Basic)

      # Then: First trick is complete
      assert length(game_after_4.tricks_won) == 1
      assert length(game_after_4.current_trick.cards) == 0
    end

    test "bot plays a full game (8 tricks) without errors" do
      # Given: A fresh game
      game = Game.new(:spades) |> Game.deal_cards()

      # When: Bots play all 32 cards (8 tricks × 4 cards)
      final_game = play_full_game(game, Basic, 32)

      # Then: Game is complete
      assert Game.game_over?(final_game)
      assert length(final_game.tricks_won) == 8

      # And: All cards have been played
      total_cards_in_hands =
        final_game.players
        |> Enum.map(fn player -> length(player.hand) end)
        |> Enum.sum()

      assert total_cards_in_hands == 0
    end

    test "bot always plays valid cards according to FFB rules" do
      # Given: A game
      game = Game.new(:diamonds) |> Game.deal_cards()

      # When: Playing multiple turns
      results = play_n_turns(game, Basic, 16)

      # Then: All plays are successful (no errors)
      assert Enum.all?(results, fn result ->
        match?({:ok, _game}, result)
      end)
    end

    test "bot handles different trump suits correctly" do
      for trump_suit <- [:spades, :hearts, :diamonds, :clubs] do
        # Given: Game with specific trump
        game = Game.new(trump_suit) |> Game.deal_cards()

        # When: Bot plays a turn
        result = Game.play_bot_turn(game, Basic)

        # Then: Play is successful
        assert {:ok, _updated_game} = result
      end
    end
  end

  # Helper: Joue N tours de bot
  defp play_n_turns(game, strategy, n) do
    Enum.reduce(1..n, [], fn _turn, acc ->
      case List.last(acc) do
        nil ->
          result = Game.play_bot_turn(game, strategy)
          [result]

        {:ok, previous_game} ->
          result = Game.play_bot_turn(previous_game, strategy)
          acc ++ [result]

        {:error, _reason} = error ->
          acc ++ [error]
      end
    end)
  end

  # Helper: Joue un jeu complet
  defp play_full_game(game, strategy, cards_to_play) do
    Enum.reduce(1..cards_to_play, game, fn _i, current_game ->
      case Game.play_bot_turn(current_game, strategy) do
        {:ok, updated_game} -> updated_game
        {:error, _} -> current_game
      end
    end)
  end
end
