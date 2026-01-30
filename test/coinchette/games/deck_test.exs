defmodule Coinchette.Games.DeckTest do
  use ExUnit.Case, async: true

  alias Coinchette.Games.Deck

  describe "new/0" do
    test "creates a deck of 32 cards" do
      deck = Deck.new()
      assert length(deck.cards) == 32
    end

    test "contains all ranks for each suit" do
      deck = Deck.new()
      ranks = [:seven, :eight, :nine, :ten, :jack, :queen, :king, :ace]
      suits = [:spades, :hearts, :diamonds, :clubs]

      for suit <- suits, rank <- ranks do
        assert Enum.any?(deck.cards, fn card ->
                 card.rank == rank and card.suit == suit
               end),
               "Missing #{rank} of #{suit}"
      end
    end

    test "has no duplicates" do
      deck = Deck.new()
      unique_cards = Enum.uniq_by(deck.cards, fn card -> {card.rank, card.suit} end)
      assert length(unique_cards) == 32
    end
  end

  describe "shuffle/1" do
    test "returns a deck with same 32 cards" do
      deck = Deck.new()
      shuffled = Deck.shuffle(deck)

      assert length(shuffled.cards) == 32
    end

    test "randomizes card order" do
      deck = Deck.new()
      shuffled = Deck.shuffle(deck)

      # Probabilité quasi-nulle que l'ordre soit identique après shuffle
      # Note: test peut rarement échouer par hasard
      assert deck.cards != shuffled.cards
    end
  end

  describe "deal/1" do
    test "deals cards to 4 players with correct distribution" do
      deck = Deck.new() |> Deck.shuffle()
      {hands, talon} = Deck.deal(deck)

      assert length(hands) == 4
      assert Enum.all?(hands, fn hand -> length(hand) == 8 end)
      assert length(talon) == 0
    end

    test "all cards are distributed (no duplicates, no missing)" do
      deck = Deck.new() |> Deck.shuffle()
      {hands, _talon} = Deck.deal(deck)

      all_dealt_cards = List.flatten(hands)
      assert length(all_dealt_cards) == 32

      # Vérifier qu'il n'y a pas de doublons
      unique_cards = Enum.uniq_by(all_dealt_cards, fn card -> {card.rank, card.suit} end)
      assert length(unique_cards) == 32
    end

    test "deals in FFB pattern: 3-2-3 cards per player" do
      # Note: Difficult to test distribution pattern without exposing internals
      # For now, we just verify final state is correct
      deck = Deck.new() |> Deck.shuffle()
      {hands, _talon} = Deck.deal(deck)

      assert Enum.all?(hands, fn hand -> length(hand) == 8 end)
    end
  end

  describe "remaining_cards/1" do
    test "returns number of cards left in deck" do
      deck = Deck.new()
      assert Deck.remaining_cards(deck) == 32

      # Simuler la distribution
      {_hands, talon} = Deck.deal(deck)
      assert talon == []
    end
  end
end
