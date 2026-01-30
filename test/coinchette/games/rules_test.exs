defmodule Coinchette.Games.RulesTest do
  use ExUnit.Case, async: true

  alias Coinchette.Games.{Rules, Card, Trick, Player}

  describe "valid_cards/4 - must follow suit" do
    test "must play led suit if available" do
      hand = [
        Card.new(:ace, :spades),
        Card.new(:king, :spades),
        Card.new(:queen, :hearts)
      ]

      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ten, :spades), 0)

      player = Player.new(1, hand)
      valid = Rules.valid_cards(player, trick, :hearts, 1)

      # Doit jouer pique (couleur demandée), pas cœur
      assert length(valid) == 2
      assert Card.new(:ace, :spades) in valid
      assert Card.new(:king, :spades) in valid
      refute Card.new(:queen, :hearts) in valid
    end

    test "can play any card if led suit not in hand" do
      hand = [
        Card.new(:ace, :hearts),  # Trump
        Card.new(:king, :diamonds)
      ]

      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ten, :spades), 0)

      player = Player.new(1, hand)
      valid = Rules.valid_cards(player, trick, :hearts, 1)

      # Pas de pique en main, peut jouer n'importe quoi (mais doit couper si possible)
      assert length(valid) == 1
      assert Card.new(:ace, :hearts) in valid  # Must play trump
    end
  end

  describe "valid_cards/4 - must trump if cannot follow" do
    test "must play trump if cannot follow suit and has trump" do
      hand = [
        Card.new(:ace, :hearts),  # Trump
        Card.new(:king, :hearts), # Trump
        Card.new(:queen, :diamonds)
      ]

      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ten, :spades), 0)

      player = Player.new(1, hand)
      valid = Rules.valid_cards(player, trick, :hearts, 1)

      # Doit couper avec atout
      assert length(valid) == 2
      assert Card.new(:ace, :hearts) in valid
      assert Card.new(:king, :hearts) in valid
      refute Card.new(:queen, :diamonds) in valid
    end

    test "can discard if no trump and cannot follow" do
      hand = [
        Card.new(:ace, :diamonds),
        Card.new(:king, :clubs)
      ]

      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ten, :spades), 0)

      player = Player.new(1, hand)
      valid = Rules.valid_cards(player, trick, :hearts, 1)

      # Pas de pique, pas d'atout : peut défausser
      assert length(valid) == 2
    end
  end

  describe "valid_cards/4 - must overtrump" do
    test "must overtrump if opponent played trump" do
      hand = [
        Card.new(:jack, :hearts),  # Trump (20 pts - strongest)
        Card.new(:seven, :hearts), # Trump (0 pts - weakest)
        Card.new(:ace, :diamonds)
      ]

      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ten, :spades), 0)
        |> Trick.add_card(Card.new(:nine, :hearts), 1)  # Trump (14 pts)

      player = Player.new(2, hand)
      valid = Rules.valid_cards(player, trick, :hearts, 2)

      # Doit surcouper avec Jack (seul atout plus fort que Nine)
      assert length(valid) == 1
      assert Card.new(:jack, :hearts) in valid
      refute Card.new(:seven, :hearts) in valid
    end

    test "can play weak trump if cannot overtrump" do
      hand = [
        Card.new(:seven, :hearts), # Trump (0 pts)
        Card.new(:eight, :hearts), # Trump (0 pts)
        Card.new(:ace, :diamonds)
      ]

      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ten, :spades), 0)
        |> Trick.add_card(Card.new(:jack, :hearts), 1)  # Trump (20 pts - strongest)

      player = Player.new(2, hand)
      valid = Rules.valid_cards(player, trick, :hearts, 2)

      # Cannot overtrump Jack, can play any trump
      assert length(valid) == 2
      assert Card.new(:seven, :hearts) in valid
      assert Card.new(:eight, :hearts) in valid
    end
  end

  describe "valid_cards/4 - partner exception" do
    test "can discard if partner is winning (no trump in trick)" do
      hand = [
        Card.new(:ace, :hearts),  # Trump
        Card.new(:king, :diamonds)
      ]

      # Partner (position 0, team 0) is winning with Ace of spades
      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ace, :spades), 0)   # Partner
        |> Trick.add_card(Card.new(:seven, :spades), 1) # Opponent

      player = Player.new(2, hand)  # Position 2, team 0 (same as position 0)
      valid = Rules.valid_cards(player, trick, :hearts, 2)

      # Partner winning, can discard (no obligation to trump)
      assert length(valid) == 2
    end

    test "must overtrump if partner played trump but opponent overtrumped" do
      hand = [
        Card.new(:jack, :hearts),  # Trump (20 pts)
        Card.new(:seven, :hearts), # Trump (0 pts)
        Card.new(:ace, :diamonds)
      ]

      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ten, :spades), 0)
        |> Trick.add_card(Card.new(:eight, :hearts), 1)  # Partner's trump
        |> Trick.add_card(Card.new(:nine, :hearts), 2)   # Opponent overtrumped (14 pts)

      player = Player.new(3, hand)  # Team 1 (partner is position 1)
      valid = Rules.valid_cards(player, trick, :hearts, 3)

      # Opponent is winning, must overtrump
      assert length(valid) == 1
      assert Card.new(:jack, :hearts) in valid
    end

    test "no obligation to overtrump partner" do
      hand = [
        Card.new(:jack, :hearts),  # Trump (20 pts)
        Card.new(:seven, :hearts), # Trump (0 pts)
        Card.new(:ace, :diamonds)
      ]

      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ten, :spades), 0)   # Opponent
        |> Trick.add_card(Card.new(:nine, :hearts), 1)  # Partner's trump (14 pts)

      player = Player.new(3, hand)  # Team 1 (partner is position 1)
      valid = Rules.valid_cards(player, trick, :hearts, 3)

      # Partner winning, can play any trump (no obligation to overtrump)
      assert length(valid) == 2
      assert Card.new(:jack, :hearts) in valid
      assert Card.new(:seven, :hearts) in valid
    end
  end

  describe "valid_cards/4 - first player" do
    test "first player can play any card" do
      hand = [
        Card.new(:ace, :spades),
        Card.new(:king, :hearts),
        Card.new(:queen, :diamonds)
      ]

      trick = Trick.new()

      player = Player.new(0, hand)
      valid = Rules.valid_cards(player, trick, :hearts, 0)

      # Premier joueur, peut jouer n'importe quoi
      assert length(valid) == 3
    end
  end

  describe "can_play_card?/5" do
    test "returns true if card is in valid cards" do
      hand = [Card.new(:ace, :spades)]
      player = Player.new(0, hand)
      trick = Trick.new()

      assert Rules.can_play_card?(player, trick, :hearts, 0, Card.new(:ace, :spades))
    end

    test "returns false if card is not in valid cards" do
      hand = [
        Card.new(:ace, :spades),
        Card.new(:king, :hearts)
      ]

      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ten, :spades), 0)

      player = Player.new(1, hand)

      # Cannot play hearts when spades in hand
      refute Rules.can_play_card?(player, trick, :hearts, 1, Card.new(:king, :hearts))
    end
  end
end
