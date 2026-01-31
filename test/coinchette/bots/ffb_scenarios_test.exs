defmodule Coinchette.Bots.FFBScenariosTest do
  use ExUnit.Case, async: true

  alias Coinchette.Bots.Basic
  alias Coinchette.Games.{Card, Player, Trick}

  describe "Bot respects FFB rules in complex scenarios" do
    test "must follow suit when holding cards of led suit" do
      # Given: Trick led with hearts, bot has hearts
      led_card = Card.new(:king, :hearts)
      trick = Trick.new() |> Trick.add_card(led_card, 0)

      # Bot has both hearts and spades
      seven_hearts = Card.new(:seven, :hearts)
      eight_hearts = Card.new(:eight, :hearts)
      ace_spades = Card.new(:ace, :spades)

      player = Player.new(1, [seven_hearts, eight_hearts, ace_spades])

      # Only hearts are valid (must follow suit)
      valid_cards = [seven_hearts, eight_hearts]

      # When: Bot chooses
      chosen = Basic.choose_card(player, trick, :spades, valid_cards)

      # Then: Plays a heart (not the spade)
      assert chosen.suit == :hearts
    end

    test "must cut with trump when cannot follow suit" do
      # Given: Led with hearts, bot has no hearts but has trump
      led_card = Card.new(:king, :hearts)
      trick = Trick.new() |> Trick.add_card(led_card, 0)

      # Bot has only trump (spades)
      seven_trump = Card.new(:seven, :spades)
      nine_trump = Card.new(:nine, :spades)

      player = Player.new(1, [seven_trump, nine_trump])
      valid_cards = [seven_trump, nine_trump]

      # When: Bot chooses (spades is trump)
      chosen = Basic.choose_card(player, trick, :spades, valid_cards)

      # Then: Plays a trump
      assert chosen.suit == :spades
    end

    test "chooses lowest trump when must overtrump" do
      # Given: Partner played low, opponent cut with trump
      partner_card = Card.new(:king, :hearts)
      opponent_trump = Card.new(:eight, :spades)

      trick =
        Trick.new()
        |> Trick.add_card(partner_card, 0)
        |> Trick.add_card(opponent_trump, 1)

      # Bot must overtrump
      # Stronger trump
      nine_trump = Card.new(:nine, :spades)
      # Even stronger
      jack_trump = Card.new(:jack, :spades)

      player = Player.new(2, [nine_trump, jack_trump])
      # Both can overtrump
      valid_cards = [nine_trump, jack_trump]

      # When: Bot chooses
      chosen = Basic.choose_card(player, trick, :spades, valid_cards)

      # Then: Uses lowest trump that can overtrump (nine is stronger than eight)
      assert chosen == nine_trump
    end

    test "discards non-trump when partner is winning" do
      # Given: Partner winning with high card
      partner_ace = Card.new(:ace, :hearts)
      trick = Trick.new() |> Trick.add_card(partner_ace, 0)

      # Bot can discard (partner winning, can't follow)
      eight_clubs = Card.new(:eight, :clubs)
      seven_trump = Card.new(:seven, :spades)

      # Position 2 = same team as 0
      player = Player.new(2, [eight_clubs, seven_trump])
      valid_cards = [eight_clubs, seven_trump]

      # When: Bot chooses
      chosen = Basic.choose_card(player, trick, :spades, valid_cards)

      # Then: Discards non-trump to save trump
      assert chosen == eight_clubs
    end

    test "plays lowest card when leading (first player)" do
      # Given: Bot is first to play
      trick = Trick.new()

      seven = Card.new(:seven, :hearts)
      ace = Card.new(:ace, :hearts)
      king = Card.new(:king, :hearts)

      player = Player.new(0, [ace, king, seven])
      # All cards are valid when leading
      valid_cards = [ace, king, seven]

      # When: Bot chooses
      chosen = Basic.choose_card(player, trick, :spades, valid_cards)

      # Then: Plays lowest card (conservative strategy)
      assert chosen == seven
    end

    test "handles single trump correctly when must cut" do
      # Given: Must cut with only one trump
      led_card = Card.new(:king, :hearts)
      trick = Trick.new() |> Trick.add_card(led_card, 0)

      only_trump = Card.new(:jack, :spades)
      player = Player.new(1, [only_trump])
      valid_cards = [only_trump]

      # When: Bot chooses
      chosen = Basic.choose_card(player, trick, :spades, valid_cards)

      # Then: Plays the only trump
      assert chosen == only_trump
    end
  end
end
