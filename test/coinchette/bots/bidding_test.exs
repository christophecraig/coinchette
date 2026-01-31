defmodule Coinchette.Bots.BiddingTest do
  use ExUnit.Case, async: true

  alias Coinchette.Bots.Bidding
  alias Coinchette.Games.Card

  describe "decide_bid/3 - First round (take or pass)" do
    test "takes when hand has 2+ trumps including a strong one (Jack)" do
      # Given: hand with Jack and 9 of proposed trump
      hand = [
        Card.new(:jack, :hearts),
        Card.new(:nine, :hearts),
        Card.new(:seven, :spades),
        Card.new(:eight, :diamonds),
        Card.new(:king, :clubs)
      ]

      # When: deciding on first round with hearts proposed
      decision = Bidding.decide_bid(hand, :hearts, round: 1)

      # Then: should take
      assert decision == :take
    end

    test "takes when hand has 2+ trumps including Ace" do
      hand = [
        Card.new(:ace, :hearts),
        Card.new(:seven, :hearts),
        Card.new(:ten, :spades),
        Card.new(:king, :diamonds),
        Card.new(:queen, :clubs)
      ]

      decision = Bidding.decide_bid(hand, :hearts, round: 1)

      assert decision == :take
    end

    test "takes when hand has 3+ trumps even with weaker cards" do
      hand = [
        Card.new(:ten, :hearts),
        Card.new(:eight, :hearts),
        Card.new(:seven, :hearts),
        Card.new(:king, :spades),
        Card.new(:queen, :diamonds)
      ]

      decision = Bidding.decide_bid(hand, :hearts, round: 1)

      assert decision == :take
    end

    test "passes when hand has only 1 trump" do
      hand = [
        Card.new(:ace, :hearts),
        Card.new(:ten, :spades),
        Card.new(:king, :spades),
        Card.new(:queen, :diamonds),
        Card.new(:jack, :clubs)
      ]

      decision = Bidding.decide_bid(hand, :hearts, round: 1)

      assert decision == :pass
    end

    test "passes when hand has 2 trumps but both are weak (7, 8)" do
      hand = [
        Card.new(:seven, :hearts),
        Card.new(:eight, :hearts),
        Card.new(:ace, :spades),
        Card.new(:ten, :spades),
        Card.new(:king, :diamonds)
      ]

      decision = Bidding.decide_bid(hand, :hearts, round: 1)

      assert decision == :pass
    end

    test "passes when no trumps in hand" do
      hand = [
        Card.new(:ace, :spades),
        Card.new(:ten, :spades),
        Card.new(:king, :diamonds),
        Card.new(:queen, :diamonds),
        Card.new(:jack, :clubs)
      ]

      decision = Bidding.decide_bid(hand, :hearts, round: 1)

      assert decision == :pass
    end
  end

  describe "decide_bid/3 - Second round (choose suit or pass)" do
    test "chooses spades when it's the strongest suit with good cards" do
      hand = [
        Card.new(:jack, :spades),
        Card.new(:ace, :spades),
        Card.new(:ten, :spades),
        Card.new(:seven, :diamonds),
        Card.new(:eight, :clubs)
      ]

      decision = Bidding.decide_bid(hand, :hearts, round: 2)

      assert decision == {:choose, :spades}
    end

    test "chooses diamonds when it has 3+ cards and good strength" do
      hand = [
        Card.new(:nine, :diamonds),
        Card.new(:ace, :diamonds),
        Card.new(:king, :diamonds),
        Card.new(:seven, :spades),
        Card.new(:eight, :clubs)
      ]

      decision = Bidding.decide_bid(hand, :hearts, round: 2)

      assert decision == {:choose, :diamonds}
    end

    test "does not choose proposed trump suit" do
      hand = [
        Card.new(:jack, :hearts),
        Card.new(:ace, :hearts),
        Card.new(:ten, :hearts),
        Card.new(:seven, :spades),
        Card.new(:eight, :clubs)
      ]

      decision = Bidding.decide_bid(hand, :hearts, round: 2)

      # Should not choose hearts (proposed), should find next best or pass
      case decision do
        {:choose, suit} -> assert suit != :hearts
        :pass -> assert true
      end
    end

    test "passes when no suit is strong enough" do
      hand = [
        Card.new(:seven, :spades),
        Card.new(:eight, :spades),
        Card.new(:seven, :diamonds),
        Card.new(:eight, :diamonds),
        Card.new(:seven, :clubs)
      ]

      decision = Bidding.decide_bid(hand, :hearts, round: 2)

      assert decision == :pass
    end

    test "chooses best available suit when multiple are good" do
      hand = [
        Card.new(:jack, :spades),
        Card.new(:nine, :spades),
        Card.new(:ace, :diamonds),
        Card.new(:ten, :diamonds),
        Card.new(:seven, :clubs)
      ]

      decision = Bidding.decide_bid(hand, :hearts, round: 2)

      # Should choose either spades or diamonds (both strong)
      assert match?({:choose, suit} when suit in [:spades, :diamonds], decision)
    end
  end

  describe "Edge cases" do
    test "handles empty hand gracefully" do
      decision = Bidding.decide_bid([], :hearts, round: 1)
      assert decision == :pass
    end

    test "works with all different suits" do
      for proposed_suit <- [:spades, :hearts, :diamonds, :clubs] do
        hand = [
          Card.new(:jack, proposed_suit),
          Card.new(:nine, proposed_suit),
          Card.new(:ace, :spades),
          Card.new(:king, :hearts),
          Card.new(:queen, :diamonds)
        ]

        decision = Bidding.decide_bid(hand, proposed_suit, round: 1)
        assert decision == :take
      end
    end
  end
end
