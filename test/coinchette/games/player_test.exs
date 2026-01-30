defmodule Coinchette.Games.PlayerTest do
  use ExUnit.Case, async: true

  alias Coinchette.Games.{Player, Card}

  describe "new/2" do
    test "creates a player with position and hand" do
      hand = [Card.new(:ace, :spades), Card.new(:king, :hearts)]
      player = Player.new(0, hand)

      assert player.position == 0
      assert player.hand == hand
      assert player.team == 0
    end

    test "assigns team based on position (0 and 2 = team 0)" do
      player0 = Player.new(0, [])
      player2 = Player.new(2, [])

      assert player0.team == 0
      assert player2.team == 0
    end

    test "assigns team based on position (1 and 3 = team 1)" do
      player1 = Player.new(1, [])
      player3 = Player.new(3, [])

      assert player1.team == 1
      assert player3.team == 1
    end
  end

  describe "play_card/2" do
    test "removes card from hand" do
      card_to_play = Card.new(:ace, :spades)
      hand = [card_to_play, Card.new(:king, :hearts)]
      player = Player.new(0, hand)

      {updated_player, played_card} = Player.play_card(player, card_to_play)

      assert played_card == card_to_play
      assert length(updated_player.hand) == 1
      assert card_to_play not in updated_player.hand
    end

    test "returns error if card not in hand" do
      card_not_in_hand = Card.new(:ace, :spades)
      hand = [Card.new(:king, :hearts)]
      player = Player.new(0, hand)

      assert Player.play_card(player, card_not_in_hand) == {:error, :card_not_in_hand}
    end
  end

  describe "has_card?/2" do
    test "returns true if player has the card" do
      card = Card.new(:ace, :spades)
      player = Player.new(0, [card, Card.new(:king, :hearts)])

      assert Player.has_card?(player, card)
    end

    test "returns false if player doesn't have the card" do
      card = Card.new(:ace, :spades)
      player = Player.new(0, [Card.new(:king, :hearts)])

      refute Player.has_card?(player, card)
    end
  end

  describe "cards_of_suit/2" do
    test "returns cards matching the suit" do
      spades_ace = Card.new(:ace, :spades)
      spades_king = Card.new(:king, :spades)
      hearts_queen = Card.new(:queen, :hearts)

      player = Player.new(0, [spades_ace, hearts_queen, spades_king])
      spades = Player.cards_of_suit(player, :spades)

      assert length(spades) == 2
      assert spades_ace in spades
      assert spades_king in spades
      assert hearts_queen not in spades
    end

    test "returns empty list if no cards of suit" do
      player = Player.new(0, [Card.new(:ace, :hearts)])
      spades = Player.cards_of_suit(player, :spades)

      assert spades == []
    end
  end

  describe "hand_size/1" do
    test "returns number of cards in hand" do
      player = Player.new(0, [Card.new(:ace, :spades), Card.new(:king, :hearts)])
      assert Player.hand_size(player) == 2
    end

    test "returns 0 for empty hand" do
      player = Player.new(0, [])
      assert Player.hand_size(player) == 0
    end
  end
end
