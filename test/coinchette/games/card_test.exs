defmodule Coinchette.Games.CardTest do
  use ExUnit.Case, async: true

  alias Coinchette.Games.Card

  describe "new/2" do
    test "creates a card with rank and suit" do
      card = Card.new(:ace, :hearts)

      assert card.rank == :ace
      assert card.suit == :hearts
    end

    test "accepts all valid ranks" do
      ranks = [:seven, :eight, :nine, :ten, :jack, :queen, :king, :ace]

      for rank <- ranks do
        card = Card.new(rank, :spades)
        assert card.rank == rank
      end
    end

    test "accepts all valid suits" do
      suits = [:spades, :hearts, :diamonds, :clubs]

      for suit <- suits do
        card = Card.new(:ace, suit)
        assert card.suit == suit
      end
    end
  end

  describe "value/2 - trump cards" do
    test "jack of trumps is worth 20 points" do
      card = Card.new(:jack, :hearts)
      assert Card.value(card, :hearts) == 20
    end

    test "nine of trumps is worth 14 points" do
      card = Card.new(:nine, :hearts)
      assert Card.value(card, :hearts) == 14
    end

    test "ace of trumps is worth 11 points" do
      card = Card.new(:ace, :hearts)
      assert Card.value(card, :hearts) == 11
    end

    test "ten of trumps is worth 10 points" do
      card = Card.new(:ten, :hearts)
      assert Card.value(card, :hearts) == 10
    end

    test "king of trumps is worth 4 points" do
      card = Card.new(:king, :hearts)
      assert Card.value(card, :hearts) == 4
    end

    test "queen of trumps is worth 3 points" do
      card = Card.new(:queen, :hearts)
      assert Card.value(card, :hearts) == 3
    end

    test "eight and seven of trumps are worth 0 points" do
      eight = Card.new(:eight, :hearts)
      seven = Card.new(:seven, :hearts)

      assert Card.value(eight, :hearts) == 0
      assert Card.value(seven, :hearts) == 0
    end
  end

  describe "value/2 - non-trump cards" do
    test "ace is worth 11 points" do
      card = Card.new(:ace, :spades)
      assert Card.value(card, :hearts) == 11
    end

    test "ten is worth 10 points" do
      card = Card.new(:ten, :spades)
      assert Card.value(card, :hearts) == 10
    end

    test "king is worth 4 points" do
      card = Card.new(:king, :spades)
      assert Card.value(card, :hearts) == 4
    end

    test "queen is worth 3 points" do
      card = Card.new(:queen, :spades)
      assert Card.value(card, :hearts) == 3
    end

    test "jack is worth 2 points" do
      card = Card.new(:jack, :spades)
      assert Card.value(card, :hearts) == 2
    end

    test "nine, eight, seven are worth 0 points" do
      nine = Card.new(:nine, :spades)
      eight = Card.new(:eight, :spades)
      seven = Card.new(:seven, :spades)

      assert Card.value(nine, :hearts) == 0
      assert Card.value(eight, :hearts) == 0
      assert Card.value(seven, :hearts) == 0
    end
  end

  describe "to_string/1" do
    test "returns human-readable card representation" do
      card = Card.new(:ace, :hearts)
      assert to_string(card) =~ "Ace"
      assert to_string(card) =~ "Hearts"
    end
  end
end
