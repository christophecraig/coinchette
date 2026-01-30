defmodule Coinchette.Games.GameTest do
  use ExUnit.Case, async: true

  alias Coinchette.Games.{Game, Card, Player}

  describe "new/1" do
    test "creates a new game with trump suit" do
      game = Game.new(:hearts)

      assert game.trump_suit == :hearts
      assert game.status == :waiting
      assert length(game.players) == 0
      assert game.current_trick == nil
      assert game.current_player_position == 0
    end
  end

  describe "deal_cards/1" do
    test "deals cards to 4 players" do
      game =
        Game.new(:hearts)
        |> Game.deal_cards()

      assert length(game.players) == 4
      assert Enum.all?(game.players, fn player -> length(player.hand) == 8 end)
      assert game.status == :playing
    end

    test "each player gets unique cards" do
      game =
        Game.new(:hearts)
        |> Game.deal_cards()

      all_cards =
        game.players
        |> Enum.flat_map(fn player -> player.hand end)

      unique_cards = Enum.uniq_by(all_cards, fn card -> {card.rank, card.suit} end)
      assert length(unique_cards) == 32
    end

    test "initializes empty current trick" do
      game =
        Game.new(:hearts)
        |> Game.deal_cards()

      assert game.current_trick.cards == []
    end
  end

  describe "play_card/2" do
    setup do
      game = Game.new(:hearts) |> Game.deal_cards()
      {:ok, game: game}
    end

    test "allows current player to play a card from their hand", %{game: game} do
      current_player = Enum.at(game.players, 0)
      card_to_play = List.first(current_player.hand)

      {:ok, updated_game} = Game.play_card(game, card_to_play)

      updated_player = Enum.at(updated_game.players, 0)
      assert length(updated_player.hand) == 7
      assert card_to_play not in updated_player.hand
      assert {card_to_play, 0} in updated_game.current_trick.cards
    end

    test "advances to next player after card played", %{game: game} do
      current_player = Enum.at(game.players, 0)
      card = List.first(current_player.hand)

      {:ok, updated_game} = Game.play_card(game, card)

      assert updated_game.current_player_position == 1
    end

    test "returns error if card not in current player's hand", %{game: game} do
      # Get a card from player 1's hand
      other_player = Enum.at(game.players, 1)
      other_card = List.first(other_player.hand)

      # Try to play it as player 0 (current player)
      # Returns :invalid_card because Rules check happens first
      assert Game.play_card(game, other_card) == {:error, :invalid_card}
    end

    test "returns error if card violates FFB rules", %{game: game} do
      # Ensure player 0 has both spades and hearts
      spades_card = Card.new(:ace, :spades)
      hearts_card = Card.new(:king, :hearts)

      player0 = %{Player.new(0, [spades_card, hearts_card]) | team: 0}
      game = %{game | players: [player0 | Enum.drop(game.players, 1)]}

      # Player 0 plays spades (led suit)
      {:ok, game} = Game.play_card(game, spades_card)

      # Now player 1 must have spades in hand for this test
      # We'll create a controlled scenario
      spades_seven = Card.new(:seven, :spades)
      hearts_queen = Card.new(:queen, :hearts)

      player1 = %{Player.new(1, [spades_seven, hearts_queen]) | team: 1}
      game = %{game | players: List.replace_at(game.players, 1, player1)}

      # Try to play hearts when spades is required
      assert Game.play_card(game, hearts_queen) == {:error, :invalid_card}
    end

    test "completes trick after 4 cards and starts new one", %{game: game} do
      alias Coinchette.Games.Rules

      # Play 4 cards (one complete trick) with valid moves
      game =
        Enum.reduce(0..3, game, fn _, acc ->
          current_player = Enum.at(acc.players, acc.current_player_position)

          # Get valid cards and play first one
          valid_cards =
            Rules.valid_cards(
              current_player,
              acc.current_trick,
              acc.trump_suit,
              current_player.position
            )

          card = List.first(valid_cards)
          {:ok, updated} = Game.play_card(acc, card)
          updated
        end)

      # Trick should be complete and a new one started
      assert game.current_trick.cards == []
      assert length(game.tricks_won) == 1
    end
  end

  describe "current_player/1" do
    test "returns the player whose turn it is" do
      game = Game.new(:hearts) |> Game.deal_cards()

      player = Game.current_player(game)
      assert player.position == 0
    end
  end

  describe "game_over?/1" do
    test "returns false at start of game" do
      game = Game.new(:hearts) |> Game.deal_cards()
      refute Game.game_over?(game)
    end

    test "returns true when all 8 tricks played" do
      game =
        Game.new(:hearts)
        |> Game.deal_cards()
        |> play_full_round()

      assert Game.game_over?(game)
    end
  end

  describe "winner/1" do
    test "returns team with most tricks won" do
      game =
        Game.new(:hearts)
        |> Game.deal_cards()
        |> play_full_round()

      winner = Game.winner(game)
      assert winner in [0, 1]
    end
  end

  # Helper function to play a full round (8 tricks = 32 cards)
  # Plays legal cards according to FFB rules
  defp play_full_round(game) do
    Enum.reduce(1..32, game, fn _, acc ->
      current_player = Enum.at(acc.players, acc.current_player_position)

      # Get valid cards according to FFB rules
      alias Coinchette.Games.Rules

      valid_cards =
        Rules.valid_cards(
          current_player,
          acc.current_trick,
          acc.trump_suit,
          current_player.position
        )

      # Play first valid card
      card = List.first(valid_cards)
      {:ok, updated} = Game.play_card(acc, card)
      updated
    end)
  end
end
