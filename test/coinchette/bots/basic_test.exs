defmodule Coinchette.Bots.BasicTest do
  use ExUnit.Case, async: true

  alias Coinchette.Bots.Basic
  alias Coinchette.Games.{Card, Player, Trick}

  describe "choose_card/4" do
    test "chooses the only card when only one valid card" do
      # Given: Bot has only one valid card
      valid_card = Card.new(:seven, :hearts)
      player = Player.new(0, [valid_card])
      trick = Trick.new()

      # When: Bot chooses
      chosen = Basic.choose_card(player, trick, :spades, [valid_card])

      # Then: Returns the only valid card
      assert chosen == valid_card
    end

    test "chooses smallest card when multiple valid cards (no trump)" do
      # Given: Bot has multiple cards, none are trump
      seven = Card.new(:seven, :hearts)
      ace = Card.new(:ace, :hearts)
      king = Card.new(:king, :hearts)

      player = Player.new(0, [ace, king, seven])
      trick = Trick.new()
      valid_cards = [ace, king, seven]

      # When: Bot chooses (hearts is not trump)
      chosen = Basic.choose_card(player, trick, :spades, valid_cards)

      # Then: Chooses smallest (seven)
      assert chosen == seven
    end

    test "chooses smallest card when multiple trump cards available" do
      # Given: Bot has multiple trump cards
      seven_trump = Card.new(:seven, :hearts)
      jack_trump = Card.new(:jack, :hearts)
      nine_trump = Card.new(:nine, :hearts)

      player = Player.new(0, [jack_trump, nine_trump, seven_trump])
      trick = Trick.new()
      valid_cards = [jack_trump, nine_trump, seven_trump]

      # When: Bot chooses (hearts is trump)
      chosen = Basic.choose_card(player, trick, :hearts, valid_cards)

      # Then: Chooses smallest trump (seven)
      # Note: Smallest in strength, not rank
      assert chosen == seven_trump
    end

    test "chooses smallest card when must follow suit" do
      # Given: Trick started with hearts, bot must follow
      led_card = Card.new(:king, :hearts)
      trick = Trick.new() |> Trick.add_card(led_card, 0)

      eight_hearts = Card.new(:eight, :hearts)
      ace_hearts = Card.new(:ace, :hearts)
      player = Player.new(1, [ace_hearts, eight_hearts])
      valid_cards = [ace_hearts, eight_hearts]

      # When: Bot chooses
      chosen = Basic.choose_card(player, trick, :spades, valid_cards)

      # Then: Chooses smallest (eight)
      assert chosen == eight_hearts
    end

    test "chooses smallest trump when must cut" do
      # Given: Bot must cut (doesn't have led suit)
      led_card = Card.new(:king, :hearts)
      trick = Trick.new() |> Trick.add_card(led_card, 0)

      seven_trump = Card.new(:seven, :spades)
      jack_trump = Card.new(:jack, :spades)
      player = Player.new(1, [jack_trump, seven_trump])
      valid_cards = [jack_trump, seven_trump]

      # When: Bot must cut with spades (trump)
      chosen = Basic.choose_card(player, trick, :spades, valid_cards)

      # Then: Chooses smallest trump
      assert chosen == seven_trump
    end

    test "handles edge case with one card in hand" do
      # Given: Bot has only one card total
      only_card = Card.new(:ace, :spades)
      player = Player.new(2, [only_card])
      trick = Trick.new()

      # When: Bot chooses
      chosen = Basic.choose_card(player, trick, :hearts, [only_card])

      # Then: Returns that card
      assert chosen == only_card
    end

    test "prefers non-trump over trump when possible (discard scenario)" do
      # Given: Bot can discard (partner winning, can't follow suit)
      led_card = Card.new(:king, :hearts)
      trick = Trick.new() |> Trick.add_card(led_card, 0)

      # Bot has both trump and non-trump available
      seven_trump = Card.new(:seven, :spades)
      eight_clubs = Card.new(:eight, :clubs)
      player = Player.new(1, [seven_trump, eight_clubs])

      # Both are valid (can discard freely)
      valid_cards = [seven_trump, eight_clubs]

      # When: Bot chooses (spades is trump)
      chosen = Basic.choose_card(player, trick, :spades, valid_cards)

      # Then: Prefers to discard non-trump to save trump
      # (Smallest by strength, non-trump cards have lower priority)
      assert chosen == eight_clubs
    end
  end
end
