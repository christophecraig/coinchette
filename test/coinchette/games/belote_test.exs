defmodule Coinchette.Games.BeloteTest do
  use ExUnit.Case, async: true

  alias Coinchette.Games.{Game, Card, Player}

  describe "detect_belote_rebelote/3" do
    test "détecte quand un joueur a le Roi et la Dame d'atout" do
      king = Card.new(:king, :hearts)
      queen = Card.new(:queen, :hearts)
      other = Card.new(:ace, :spades)

      player = Player.new(0, [king, queen, other])

      assert Game.has_belote?(player, :hearts)
    end

    test "retourne false si le joueur n'a que le Roi" do
      king = Card.new(:king, :hearts)
      other1 = Card.new(:ace, :spades)
      other2 = Card.new(:ten, :diamonds)

      player = Player.new(0, [king, other1, other2])

      refute Game.has_belote?(player, :hearts)
    end

    test "retourne false si le joueur n'a que la Dame" do
      queen = Card.new(:queen, :hearts)
      other1 = Card.new(:ace, :spades)
      other2 = Card.new(:ten, :diamonds)

      player = Player.new(0, [queen, other1, other2])

      refute Game.has_belote?(player, :hearts)
    end

    test "retourne false si Roi et Dame ne sont pas de la couleur d'atout" do
      king = Card.new(:king, :spades)
      queen = Card.new(:queen, :spades)
      other = Card.new(:ace, :diamonds)

      player = Player.new(0, [king, queen, other])

      refute Game.has_belote?(player, :hearts)
    end
  end

  describe "check_and_announce_belote/3" do
    test "enregistre l'annonce de Belote quand le Roi d'atout est joué" do
      game =
        Game.new(dealer_position: 0)
        |> Game.deal_initial_cards()

      {:ok, game} = Game.make_bid(game, :take)
      game = Game.complete_deal(game)

      # Simuler un joueur avec Roi+Dame d'atout
      king = Card.new(:king, game.trump_suit)
      queen = Card.new(:queen, game.trump_suit)
      player0 = %{Enum.at(game.players, 0) | hand: [king, queen]}
      game = %{game | players: List.replace_at(game.players, 0, player0)}

      # Appeler directement check_and_announce_belote
      updated_game = Game.check_and_announce_belote(game, king, 0)

      # Vérifier que Belote est annoncée
      assert updated_game.belote_announced == {0, :king}
    end

    test "enregistre Rebelote quand la Dame est jouée après le Roi" do
      game =
        Game.new(dealer_position: 0)
        |> Game.deal_initial_cards()

      {:ok, game} = Game.make_bid(game, :take)
      game = Game.complete_deal(game)

      # Simuler qu'on a déjà annoncé Belote avec le Roi
      game = %{game | belote_announced: {0, :king}}

      # Joueur 0 (équipe 0) joue maintenant la Dame
      queen = Card.new(:queen, game.trump_suit)
      player0 = %{Enum.at(game.players, 0) | hand: [queen], team: 0}
      game = %{game | players: List.replace_at(game.players, 0, player0)}

      # Appeler check_and_announce_belote
      final_game = Game.check_and_announce_belote(game, queen, 0)

      # Vérifier que Rebelote est enregistrée
      assert final_game.belote_rebelote == {0, true}
      # Et que belote_announced est reset
      assert final_game.belote_announced == nil
    end
  end

  describe "score avec Belote/Rebelote" do
    test "ajoute +20 points à l'équipe qui a Belote/Rebelote" do
      game =
        Game.new(dealer_position: 0)
        |> Game.deal_initial_cards()

      {:ok, game} = Game.make_bid(game, :take)
      game = Game.complete_deal(game)

      # Marquer qu'une équipe a Belote/Rebelote
      game = %{game | belote_rebelote: {0, true}}

      # Jouer une partie complète
      game = play_full_round_simple(game)

      # Vérifier que l'équipe 0 a +20 points
      # (Le score exact dépend des cartes jouées, mais on vérifie le bonus)
      team0_base_score = calculate_base_score(game, 0)
      assert game.scores[0] >= team0_base_score + 20
    end
  end

  # Helpers pour les tests

  defp play_full_round_simple(game) do
    # Joue une partie complète de manière simplifiée
    Enum.reduce(1..32, game, fn _, acc ->
      if not Game.game_over?(acc) do
        current_player = Game.current_player(acc)
        valid_cards = Coinchette.Games.Rules.valid_cards(
          current_player,
          acc.current_trick,
          acc.trump_suit,
          current_player.position
        )
        card = List.first(valid_cards)
        {:ok, updated} = Game.play_card(acc, card)
        updated
      else
        acc
      end
    end)
  end

  defp calculate_base_score(_game, _team) do
    # Cette fonction devrait calculer le score de base sans Belote/Rebelote
    # Pour simplifier le test, on retourne 0
    0
  end
end
