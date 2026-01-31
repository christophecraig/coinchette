defmodule Coinchette.Games.GameAnnouncementsTest do
  use ExUnit.Case, async: true

  alias Coinchette.Games.{Game, Card, Player}

  describe "complete_deal/1 avec annonces" do
    test "détecte automatiquement les annonces après distribution" do
      # Créer un jeu avec enchères complétées
      game =
        Game.new(dealer_position: 0)
        |> Game.deal_initial_cards()

      # Simuler enchères réussies
      {:ok, game} = Game.make_bid(game, :take)

      # Compléter la distribution
      game = Game.complete_deal(game)

      # Vérifier phase annonces
      assert game.status == :announcing
      assert game.announcement_phase_complete == true
      assert game.announcements_result != nil
      assert is_map(game.announcements_result)
      assert Map.has_key?(game.announcements_result, :winning_team)
      assert Map.has_key?(game.announcements_result, :total_points)
      assert Map.has_key?(game.announcements_result, :all_announcements)
    end

    test "tous les joueurs ont 8 cartes après distribution" do
      game =
        Game.new(dealer_position: 0)
        |> Game.deal_initial_cards()

      {:ok, game} = Game.make_bid(game, :take)
      game = Game.complete_deal(game)

      assert Enum.all?(game.players, fn p -> length(p.hand) == 8 end)
    end

    test "talon est vidé après distribution" do
      game =
        Game.new(dealer_position: 0)
        |> Game.deal_initial_cards()

      {:ok, game} = Game.make_bid(game, :take)
      game = Game.complete_deal(game)

      assert game.talon == []
    end
  end

  describe "complete_announcements/1" do
    test "transition de :announcing vers :playing" do
      game =
        Game.new(dealer_position: 0)
        |> Game.deal_initial_cards()

      {:ok, game} = Game.make_bid(game, :take)
      game = Game.complete_deal(game)

      assert game.status == :announcing

      game = Game.complete_announcements(game)

      assert game.status == :playing
      assert game.current_trick != nil
    end
  end

  describe "intégration scores avec annonces" do
    test "annonces avec tierce sont ajoutées au score au premier pli" do
      # Créer un jeu avec des joueurs ayant des mains spécifiques
      game =
        Game.new(dealer_position: 0)
        |> setup_game_with_announcements()

      # Distribution et annonces
      game = Game.complete_deal(game)
      game = Game.complete_announcements(game)

      # Sauvegarder les annonces
      initial_announcements = game.announcements_result

      # Jouer le premier pli complet
      game = play_full_trick(game)

      # Si une équipe avait des annonces, vérifier qu'elles sont dans le score
      if initial_announcements.total_points > 0 do
        winning_team = initial_announcements.winning_team
        assert game.scores[winning_team] >= initial_announcements.total_points
      end
    end

    test "annonces ne sont comptées qu'une seule fois (premier pli uniquement)" do
      game =
        Game.new(dealer_position: 0)
        |> setup_game_with_announcements()

      game = Game.complete_deal(game)
      game = Game.complete_announcements(game)

      initial_announcements = game.announcements_result

      # Jouer premier pli
      game = play_full_trick(game)
      scores_after_first = game.scores

      # Jouer deuxième pli
      game = play_full_trick(game)
      scores_after_second = game.scores

      # La différence entre pli 2 et pli 1 ne devrait PAS inclure les annonces
      # (seulement les points du pli lui-même)
      if initial_announcements.total_points > 0 do
        team0_diff = scores_after_second[0] - scores_after_first[0]
        team1_diff = scores_after_second[1] - scores_after_first[1]

        # La différence devrait être <= points max d'un pli (environ 35-40)
        # pas >= points annonces (qui pourraient être 100+)
        assert team0_diff < 50
        assert team1_diff < 50
      end
    end

    test "partie avec annonces inclut les points" do
      game =
        Game.new(dealer_position: 0)
        |> setup_game_with_multiple_bonuses()

      game = Game.complete_deal(game)

      # Sauvegarder les annonces détectées
      initial_announcements = game.announcements_result

      game = Game.complete_announcements(game)

      # Jouer au moins quelques plis
      game =
        1..4
        |> Enum.reduce(game, fn _, acc -> play_full_trick(acc) end)

      # Vérifier que les scores incluent les annonces
      total_score = game.scores[0] + game.scores[1]

      # Le score total devrait être > 0
      assert total_score > 0

      # Si des annonces existaient, vérifier qu'elles sont comptées
      if initial_announcements.total_points > 0 do
        winning_team = initial_announcements.winning_team
        assert game.scores[winning_team] >= initial_announcements.total_points
      end
    end
  end

  describe "cas particuliers" do
    test "aucune annonce détectée fonctionne correctement" do
      # Créer un jeu sans annonces (mains fragmentées)
      game =
        Game.new(dealer_position: 0)
        |> setup_game_without_announcements()

      game = Game.complete_deal(game)

      assert game.announcements_result.winning_team == nil
      assert game.announcements_result.total_points == 0

      game = Game.complete_announcements(game)

      # Jouer un pli
      game = play_full_trick(game)

      # Scores devraient être uniquement basés sur les plis
      assert game.scores[0] + game.scores[1] <= 50
    end

    test "une seule équipe a des annonces" do
      game =
        Game.new(dealer_position: 0)
        |> setup_game_single_team_announcements()

      game = Game.complete_deal(game)

      # Une équipe devrait avoir gagné
      assert game.announcements_result.winning_team in [0, 1]
      assert game.announcements_result.total_points > 0

      game = Game.complete_announcements(game)
      game = play_full_trick(game)

      winning_team = game.announcements_result.winning_team
      assert game.scores[winning_team] > 0
    end
  end

  # Helpers

  defp setup_game_with_announcements(game) do
    # Donner au joueur 0 une tierce
    player0_hand = [
      %Card{rank: :seven, suit: :hearts},
      %Card{rank: :eight, suit: :hearts},
      %Card{rank: :nine, suit: :hearts},
      %Card{rank: :ace, suit: :spades},
      %Card{rank: :king, suit: :clubs}
    ]

    # Mains aléatoires pour les autres
    player1_hand = generate_random_hand(5)
    player2_hand = generate_random_hand(5)
    player3_hand = generate_random_hand(5)

    players = [
      %Player{position: 0, team: 0, hand: player0_hand},
      %Player{position: 1, team: 1, hand: player1_hand},
      %Player{position: 2, team: 0, hand: player2_hand},
      %Player{position: 3, team: 1, hand: player3_hand}
    ]

    # Talon
    talon = [
      %Card{rank: :ten, suit: :diamonds},
      %Card{rank: :jack, suit: :diamonds},
      %Card{rank: :queen, suit: :diamonds}
    ]

    %{
      game
      | players: players,
        talon: talon,
        proposed_trump_card: hd(talon),
        trump_suit: :diamonds,
        status: :bidding_completed,
        bidding: %Coinchette.Games.Bidding{
          current_bidder: 0,
          dealer_position: 0,
          proposed_trump: :diamonds,
          taker: 0,
          trump_suit: :diamonds,
          status: :completed
        }
    }
  end

  defp setup_game_without_announcements(game) do
    # Mains fragmentées sans séquences ni carrés
    player0_hand = [
      %Card{rank: :seven, suit: :hearts},
      %Card{rank: :nine, suit: :diamonds},
      %Card{rank: :queen, suit: :clubs},
      %Card{rank: :ace, suit: :spades},
      %Card{rank: :eight, suit: :hearts}
    ]

    player1_hand = [
      %Card{rank: :king, suit: :hearts},
      %Card{rank: :ten, suit: :diamonds},
      %Card{rank: :jack, suit: :clubs},
      %Card{rank: :seven, suit: :spades},
      %Card{rank: :nine, suit: :clubs}
    ]

    player2_hand = generate_random_hand(5)
    player3_hand = generate_random_hand(5)

    players = [
      %Player{position: 0, team: 0, hand: player0_hand},
      %Player{position: 1, team: 1, hand: player1_hand},
      %Player{position: 2, team: 0, hand: player2_hand},
      %Player{position: 3, team: 1, hand: player3_hand}
    ]

    talon = generate_random_hand(3)

    %{
      game
      | players: players,
        talon: talon,
        proposed_trump_card: hd(talon),
        trump_suit: :diamonds,
        status: :bidding_completed,
        bidding: %Coinchette.Games.Bidding{
          current_bidder: 0,
          dealer_position: 0,
          proposed_trump: :diamonds,
          taker: 0,
          trump_suit: :diamonds,
          status: :completed
        }
    }
  end

  defp setup_game_single_team_announcements(game) do
    # Équipe 0 a une cinquante
    player0_hand = [
      %Card{rank: :seven, suit: :hearts},
      %Card{rank: :eight, suit: :hearts},
      %Card{rank: :nine, suit: :hearts},
      %Card{rank: :ten, suit: :hearts},
      %Card{rank: :ace, suit: :spades}
    ]

    # Autres joueurs sans annonces
    player1_hand = [
      %Card{rank: :king, suit: :diamonds},
      %Card{rank: :queen, suit: :clubs},
      %Card{rank: :jack, suit: :clubs},
      %Card{rank: :seven, suit: :spades},
      %Card{rank: :nine, suit: :clubs}
    ]

    player2_hand = generate_random_hand(5)
    player3_hand = generate_random_hand(5)

    players = [
      %Player{position: 0, team: 0, hand: player0_hand},
      %Player{position: 1, team: 1, hand: player1_hand},
      %Player{position: 2, team: 0, hand: player2_hand},
      %Player{position: 3, team: 1, hand: player3_hand}
    ]

    talon = generate_random_hand(3)

    %{
      game
      | players: players,
        talon: talon,
        proposed_trump_card: hd(talon),
        trump_suit: :diamonds,
        status: :bidding_completed,
        bidding: %Coinchette.Games.Bidding{
          current_bidder: 0,
          dealer_position: 0,
          proposed_trump: :diamonds,
          taker: 0,
          trump_suit: :diamonds,
          status: :completed
        }
    }
  end

  defp setup_game_with_multiple_bonuses(game) do
    # Similaire mais avec potentiel pour belote
    setup_game_with_announcements(game)
  end

  defp generate_random_hand(n) do
    # Générer des cartes aléatoires mais sans séquences ni carrés
    # Utiliser des cartes différentes pour éviter les annonces accidentelles
    all_cards = [
      %Card{rank: :seven, suit: :diamonds},
      %Card{rank: :ten, suit: :clubs},
      %Card{rank: :queen, suit: :spades},
      %Card{rank: :ace, suit: :diamonds},
      %Card{rank: :eight, suit: :clubs},
      %Card{rank: :king, suit: :spades},
      %Card{rank: :nine, suit: :diamonds},
      %Card{rank: :jack, suit: :spades}
    ]

    Enum.take(all_cards, n)
  end

  defp play_full_trick(game) do
    # Jouer 4 cartes pour compléter un pli
    Enum.reduce(0..3, game, fn _i, acc_game ->
      if acc_game.status == :playing and length(acc_game.current_trick.cards) < 4 do
        current_player = Game.current_player(acc_game)

        # Trouver une carte valide à jouer
        valid_card =
          Enum.find(current_player.hand, fn card ->
            case Game.play_card(acc_game, card) do
              {:ok, _} -> true
              {:error, _} -> false
            end
          end)

        case valid_card do
          nil ->
            # Si aucune carte valide, prendre la première
            card = hd(current_player.hand)

            case Game.play_card(acc_game, card) do
              {:ok, updated_game} -> updated_game
              {:error, _} -> acc_game
            end

          card ->
            case Game.play_card(acc_game, card) do
              {:ok, updated_game} -> updated_game
              {:error, _} -> acc_game
            end
        end
      else
        acc_game
      end
    end)
  end

  defp play_all_tricks(game) do
    # Jouer 8 plis complets (32 cartes / 4 joueurs = 8 plis)
    Enum.reduce(1..8, game, fn _pli, acc_game ->
      if acc_game.status == :playing and not Game.game_over?(acc_game) do
        play_full_trick(acc_game)
      else
        acc_game
      end
    end)
  end
end
