defmodule Coinchette.Games.GameTest do
  use ExUnit.Case, async: true

  alias Coinchette.Games.{Game, Card, Player, Bidding}

  describe "new/0" do
    test "creates a new game without trump suit (to be determined by bidding)" do
      game = Game.new()

      assert game.trump_suit == nil
      assert game.status == :waiting
      assert length(game.players) == 0
      assert game.current_trick == nil
      assert game.dealer_position == 0
      assert game.bidding == nil
    end

    test "creates a new game with specified dealer position" do
      game = Game.new(dealer_position: 2)

      assert game.dealer_position == 2
    end
  end

  describe "deal_initial_cards/1" do
    test "distribue 5 cartes à chaque joueur (3 + 2)" do
      game =
        Game.new()
        |> Game.deal_initial_cards()

      assert length(game.players) == 4
      assert Enum.all?(game.players, fn player -> length(player.hand) == 5 end)
      assert game.status == :bidding
    end

    test "garde 3 cartes au talon avec une carte retournée" do
      game =
        Game.new()
        |> Game.deal_initial_cards()

      assert length(game.talon) == 3
      assert %Card{} = game.proposed_trump_card
    end

    test "initialise la phase d'enchères" do
      game =
        Game.new(dealer_position: 0)
        |> Game.deal_initial_cards()

      assert %Bidding{} = game.bidding
      # À droite du donneur
      assert game.bidding.current_bidder == 1
      assert game.bidding.round == 1
      assert game.bidding.status == :in_progress
    end

    test "toutes les cartes sont uniques (5 x 4 + 3 = 23 cartes distribuées)" do
      game =
        Game.new()
        |> Game.deal_initial_cards()

      all_cards =
        game.players
        |> Enum.flat_map(fn player -> player.hand end)
        |> Kernel.++(game.talon)

      unique_cards = Enum.uniq_by(all_cards, fn card -> {card.rank, card.suit} end)
      assert length(unique_cards) == 23
    end
  end

  describe "make_bid/2" do
    setup do
      game = Game.new(dealer_position: 0) |> Game.deal_initial_cards()
      %{game: game}
    end

    test "joueur prend la couleur proposée", %{game: game} do
      {:ok, updated} = Game.make_bid(game, :take)

      assert updated.bidding.status == :completed
      assert updated.bidding.taker == 1
      assert updated.trump_suit == updated.proposed_trump_card.suit
      assert updated.status == :bidding_completed
    end

    test "joueur passe, passe au suivant", %{game: game} do
      {:ok, updated} = Game.make_bid(game, :pass)

      assert updated.bidding.current_bidder == 2
      assert updated.status == :bidding
    end

    test "tous passent au premier tour, passe au second tour", %{game: game} do
      # Joueur 1
      {:ok, g1} = Game.make_bid(game, :pass)
      # Joueur 2
      {:ok, g2} = Game.make_bid(g1, :pass)
      # Joueur 3
      {:ok, g3} = Game.make_bid(g2, :pass)
      # Joueur 4 (donneur)
      {:ok, g4} = Game.make_bid(g3, :pass)

      assert g4.bidding.round == 2
      assert g4.status == :bidding
    end

    test "joueur choisit une autre couleur au second tour", %{game: game} do
      # Passer le premier tour
      {:ok, g1} = Game.make_bid(game, :pass)
      {:ok, g2} = Game.make_bid(g1, :pass)
      {:ok, g3} = Game.make_bid(g2, :pass)
      {:ok, g4} = Game.make_bid(g3, :pass)

      # Second tour - choisir autre couleur
      other_suit = if g4.proposed_trump_card.suit == :hearts, do: :spades, else: :hearts
      {:ok, updated} = Game.make_bid(g4, {:choose, other_suit})

      assert updated.trump_suit == other_suit
      assert updated.bidding.status == :completed
      assert updated.status == :bidding_completed
    end

    test "erreur si pas le tour du joueur actuel" do
      # Ce test sera implémenté si on veut vérifier l'identité du joueur
      # Pour MVP, on fait confiance que c'est le bon joueur
    end

    test "erreur si enchères déjà terminées", %{game: game} do
      {:ok, completed} = Game.make_bid(game, :take)

      assert {:error, :bidding_already_completed} = Game.make_bid(completed, :pass)
    end
  end

  describe "complete_deal/1" do
    setup do
      game = Game.new(dealer_position: 0) |> Game.deal_initial_cards()
      {:ok, game_with_bid} = Game.make_bid(game, :take)
      %{game: game_with_bid}
    end

    test "donne le talon au preneur et distribue 2 cartes supplémentaires à chacun", %{game: game} do
      updated = Game.complete_deal(game)

      # Chaque joueur a maintenant 8 cartes
      assert Enum.all?(updated.players, fn player -> length(player.hand) == 8 end)

      # Le talon est maintenant vide
      assert updated.talon == []

      # Total des cartes : 8 x 4 = 32
      all_cards = Enum.flat_map(updated.players, fn player -> player.hand end)
      unique_cards = Enum.uniq_by(all_cards, fn card -> {card.rank, card.suit} end)
      assert length(unique_cards) == 32
    end

    test "démarre la phase d'annonces (status = announcing)", %{game: game} do
      updated = Game.complete_deal(game)

      assert updated.status == :announcing
      assert updated.current_trick != nil
      assert updated.announcement_phase_complete == true
    end

    test "le joueur à droite du donneur commence", %{game: game} do
      updated = Game.complete_deal(game)

      # Joueur à droite du donneur (position 1 si donneur = 0)
      expected_position = rem(updated.dealer_position + 1, 4)
      assert updated.current_player_position == expected_position
    end
  end

  describe "Flow complet avec enchères" do
    test "partie complète depuis création jusqu'à fin" do
      game =
        Game.new(dealer_position: 0)
        |> Game.deal_initial_cards()

      assert game.status == :bidding

      # Premier joueur prend
      {:ok, game} = Game.make_bid(game, :take)
      assert game.status == :bidding_completed

      # Distribution finale et annonces
      game = Game.complete_deal(game)
      assert game.status == :announcing
      assert game.trump_suit != nil

      # Compléter phase annonces
      game = Game.complete_announcements(game)
      assert game.status == :playing

      # Jouer une partie complète
      game = play_full_round(game)
      assert Game.game_over?(game)
    end

    test "tous passent aux 2 tours, redistribution nécessaire" do
      game =
        Game.new(dealer_position: 0)
        |> Game.deal_initial_cards()

      # Tous passent au premier tour
      {:ok, g1} = Game.make_bid(game, :pass)
      {:ok, g2} = Game.make_bid(g1, :pass)
      {:ok, g3} = Game.make_bid(g2, :pass)
      {:ok, g4} = Game.make_bid(g3, :pass)

      # Tous passent au second tour
      {:ok, g5} = Game.make_bid(g4, :pass)
      {:ok, g6} = Game.make_bid(g5, :pass)
      {:ok, g7} = Game.make_bid(g6, :pass)
      {:ok, g8} = Game.make_bid(g7, :pass)

      assert g8.bidding.status == :failed
      assert g8.status == :bidding_failed

      # On devrait redistribuer (pour l'instant, juste vérifier l'état)
      # En production, on appellerait deal_initial_cards à nouveau
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
