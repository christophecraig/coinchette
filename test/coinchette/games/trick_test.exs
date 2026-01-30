defmodule Coinchette.Games.TrickTest do
  use ExUnit.Case, async: true

  alias Coinchette.Games.{Trick, Card}

  describe "new/0" do
    test "creates an empty trick" do
      trick = Trick.new()

      assert trick.cards == []
      assert trick.led_suit == nil
    end
  end

  describe "add_card/3" do
    test "adds first card and sets led suit" do
      trick = Trick.new()
      card = Card.new(:ace, :spades)

      updated = Trick.add_card(trick, card, 0)

      assert length(updated.cards) == 1
      assert updated.led_suit == :spades
      assert {card, 0} in updated.cards
    end

    test "adds subsequent cards" do
      trick = Trick.new()
      first = Card.new(:ace, :spades)
      second = Card.new(:king, :spades)

      trick =
        trick
        |> Trick.add_card(first, 0)
        |> Trick.add_card(second, 1)

      assert length(trick.cards) == 2
    end

    test "returns error when trick is complete (4 cards)" do
      trick = Trick.new()

      trick =
        trick
        |> Trick.add_card(Card.new(:ace, :spades), 0)
        |> Trick.add_card(Card.new(:king, :spades), 1)
        |> Trick.add_card(Card.new(:queen, :spades), 2)
        |> Trick.add_card(Card.new(:jack, :spades), 3)

      assert Trick.add_card(trick, Card.new(:ten, :spades), 0) == {:error, :trick_complete}
    end
  end

  describe "complete?/1" do
    test "returns false for empty trick" do
      refute Trick.complete?(Trick.new())
    end

    test "returns false for partial trick" do
      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ace, :spades), 0)

      refute Trick.complete?(trick)
    end

    test "returns true when 4 cards played" do
      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ace, :spades), 0)
        |> Trick.add_card(Card.new(:king, :spades), 1)
        |> Trick.add_card(Card.new(:queen, :spades), 2)
        |> Trick.add_card(Card.new(:jack, :spades), 3)

      assert Trick.complete?(trick)
    end
  end

  describe "winner/2 - no trumps played" do
    test "highest card of led suit wins" do
      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:king, :spades), 0)
        |> Trick.add_card(Card.new(:ace, :spades), 1)
        |> Trick.add_card(Card.new(:queen, :spades), 2)
        |> Trick.add_card(Card.new(:jack, :spades), 3)

      assert Trick.winner(trick, :hearts) == 1
    end

    test "other suits don't win if led suit present" do
      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:seven, :spades), 0)
        |> Trick.add_card(Card.new(:ace, :hearts), 1)  # Not led suit
        |> Trick.add_card(Card.new(:eight, :spades), 2)
        |> Trick.add_card(Card.new(:nine, :spades), 3)

      # Position 3 wins with nine of spades (highest in led suit)
      assert Trick.winner(trick, :diamonds) == 3
    end
  end

  describe "winner/2 - trumps played" do
    test "trump beats non-trump even if lower value" do
      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ace, :spades), 0)
        |> Trick.add_card(Card.new(:seven, :hearts), 1)  # Trump
        |> Trick.add_card(Card.new(:king, :spades), 2)
        |> Trick.add_card(Card.new(:queen, :spades), 3)

      assert Trick.winner(trick, :hearts) == 1
    end

    test "highest trump wins when multiple trumps" do
      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:seven, :hearts), 0)  # Trump
        |> Trick.add_card(Card.new(:jack, :hearts), 1)   # Trump (20 pts)
        |> Trick.add_card(Card.new(:nine, :hearts), 2)   # Trump (14 pts)
        |> Trick.add_card(Card.new(:ace, :hearts), 3)    # Trump (11 pts)

      # Jack of trumps wins (highest value)
      assert Trick.winner(trick, :hearts) == 1
    end

    test "eight of trumps beats seven (even with 0 points each)" do
      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:seven, :hearts), 0)  # Trump (0 pts, strength 1)
        |> Trick.add_card(Card.new(:eight, :hearts), 1)  # Trump (0 pts, strength 2)
        |> Trick.add_card(Card.new(:king, :spades), 2)
        |> Trick.add_card(Card.new(:ace, :spades), 3)

      # Eight is stronger than seven, even though both worth 0 points
      assert Trick.winner(trick, :hearts) == 1
    end
  end

  describe "winner/2 - incomplete trick" do
    test "returns error if trick not complete" do
      trick =
        Trick.new()
        |> Trick.add_card(Card.new(:ace, :spades), 0)

      assert Trick.winner(trick, :hearts) == {:error, :trick_incomplete}
    end
  end
end
