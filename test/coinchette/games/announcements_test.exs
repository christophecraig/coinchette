defmodule Coinchette.Games.AnnouncementsTest do
  use ExUnit.Case, async: true

  alias Coinchette.Games.{Announcements, Card}

  describe "detect_sequences/2" do
    test "détecte tierce (3 cartes consécutives)" do
      hand = [
        %Card{rank: :seven, suit: :hearts},
        %Card{rank: :eight, suit: :hearts},
        %Card{rank: :nine, suit: :hearts},
        %Card{rank: :king, suit: :spades}
      ]

      result = Announcements.detect_sequences(hand, :clubs)

      assert length(result) == 1
      assert hd(result).type == :tierce
      assert hd(result).points == 20
      assert hd(result).is_trump == false
      assert length(hd(result).cards) == 3
    end

    test "détecte cinquante (4 cartes consécutives)" do
      hand = [
        %Card{rank: :ten, suit: :diamonds},
        %Card{rank: :jack, suit: :diamonds},
        %Card{rank: :queen, suit: :diamonds},
        %Card{rank: :king, suit: :diamonds}
      ]

      result = Announcements.detect_sequences(hand, :clubs)

      assert length(result) == 1
      assert hd(result).type == :cinquante
      assert hd(result).points == 50
      assert hd(result).is_trump == false
    end

    test "détecte cent (5+ cartes consécutives)" do
      hand = [
        %Card{rank: :seven, suit: :spades},
        %Card{rank: :eight, suit: :spades},
        %Card{rank: :nine, suit: :spades},
        %Card{rank: :ten, suit: :spades},
        %Card{rank: :jack, suit: :spades}
      ]

      result = Announcements.detect_sequences(hand, :clubs)

      assert length(result) == 1
      assert hd(result).type == :cent
      assert hd(result).points == 100
      assert hd(result).is_trump == false
    end

    test "préfère séquence la plus longue" do
      # 7-8-9-10-J forme une seule séquence de 5, pas tierce + cinquante
      hand = [
        %Card{rank: :seven, suit: :hearts},
        %Card{rank: :eight, suit: :hearts},
        %Card{rank: :nine, suit: :hearts},
        %Card{rank: :ten, suit: :hearts},
        %Card{rank: :jack, suit: :hearts}
      ]

      result = Announcements.detect_sequences(hand, :clubs)

      assert length(result) == 1
      assert hd(result).type == :cent
      assert length(hd(result).cards) == 5
    end

    test "détecte plusieurs séquences de couleurs différentes" do
      hand = [
        %Card{rank: :seven, suit: :hearts},
        %Card{rank: :eight, suit: :hearts},
        %Card{rank: :nine, suit: :hearts},
        %Card{rank: :jack, suit: :spades},
        %Card{rank: :queen, suit: :spades},
        %Card{rank: :king, suit: :spades}
      ]

      result = Announcements.detect_sequences(hand, :clubs)

      assert length(result) == 2
      assert Enum.all?(result, &(&1.type == :tierce))
      assert Enum.all?(result, &(&1.points == 20))
    end

    test "marque correctement séquences atout" do
      hand = [
        %Card{rank: :seven, suit: :hearts},
        %Card{rank: :eight, suit: :hearts},
        %Card{rank: :nine, suit: :hearts}
      ]

      result = Announcements.detect_sequences(hand, :hearts)

      assert length(result) == 1
      assert hd(result).is_trump == true
    end

    test "ignore séquences de 2 cartes" do
      hand = [
        %Card{rank: :seven, suit: :hearts},
        %Card{rank: :eight, suit: :hearts},
        %Card{rank: :king, suit: :spades}
      ]

      result = Announcements.detect_sequences(hand, :clubs)

      assert result == []
    end

    test "cas limite: 8 cartes consécutives" do
      hand = [
        %Card{rank: :seven, suit: :clubs},
        %Card{rank: :eight, suit: :clubs},
        %Card{rank: :nine, suit: :clubs},
        %Card{rank: :ten, suit: :clubs},
        %Card{rank: :jack, suit: :clubs},
        %Card{rank: :queen, suit: :clubs},
        %Card{rank: :king, suit: :clubs},
        %Card{rank: :ace, suit: :clubs}
      ]

      result = Announcements.detect_sequences(hand, :clubs)

      assert length(result) == 1
      assert hd(result).type == :cent
      assert hd(result).points == 100
      assert length(hd(result).cards) == 8
      assert hd(result).is_trump == true
    end
  end

  describe "detect_carres/1" do
    test "détecte carré de valets (200 points)" do
      hand = [
        %Card{rank: :jack, suit: :hearts},
        %Card{rank: :jack, suit: :diamonds},
        %Card{rank: :jack, suit: :clubs},
        %Card{rank: :jack, suit: :spades}
      ]

      result = Announcements.detect_carres(hand)

      assert length(result) == 1
      assert hd(result).type == :carre_jacks
      assert hd(result).points == 200
      assert length(hd(result).cards) == 4
    end

    test "détecte carré de 9 (150 points)" do
      hand = [
        %Card{rank: :nine, suit: :hearts},
        %Card{rank: :nine, suit: :diamonds},
        %Card{rank: :nine, suit: :clubs},
        %Card{rank: :nine, suit: :spades}
      ]

      result = Announcements.detect_carres(hand)

      assert length(result) == 1
      assert hd(result).type == :carre_nines
      assert hd(result).points == 150
    end

    test "détecte carré d'As (100 points)" do
      hand = [
        %Card{rank: :ace, suit: :hearts},
        %Card{rank: :ace, suit: :diamonds},
        %Card{rank: :ace, suit: :clubs},
        %Card{rank: :ace, suit: :spades}
      ]

      result = Announcements.detect_carres(hand)

      assert length(result) == 1
      assert hd(result).type == :carre_aces
      assert hd(result).points == 100
    end

    test "détecte carré de 10 (100 points)" do
      hand = [
        %Card{rank: :ten, suit: :hearts},
        %Card{rank: :ten, suit: :diamonds},
        %Card{rank: :ten, suit: :clubs},
        %Card{rank: :ten, suit: :spades}
      ]

      result = Announcements.detect_carres(hand)

      assert length(result) == 1
      assert hd(result).type == :carre_tens
      assert hd(result).points == 100
    end

    test "détecte carré de Roi (100 points)" do
      hand = [
        %Card{rank: :king, suit: :hearts},
        %Card{rank: :king, suit: :diamonds},
        %Card{rank: :king, suit: :clubs},
        %Card{rank: :king, suit: :spades}
      ]

      result = Announcements.detect_carres(hand)

      assert length(result) == 1
      assert hd(result).type == :carre_kings
      assert hd(result).points == 100
    end

    test "détecte carré de Dame (100 points)" do
      hand = [
        %Card{rank: :queen, suit: :hearts},
        %Card{rank: :queen, suit: :diamonds},
        %Card{rank: :queen, suit: :clubs},
        %Card{rank: :queen, suit: :spades}
      ]

      result = Announcements.detect_carres(hand)

      assert length(result) == 1
      assert hd(result).type == :carre_queens
      assert hd(result).points == 100
    end

    test "ignore carré de 7" do
      hand = [
        %Card{rank: :seven, suit: :hearts},
        %Card{rank: :seven, suit: :diamonds},
        %Card{rank: :seven, suit: :clubs},
        %Card{rank: :seven, suit: :spades}
      ]

      result = Announcements.detect_carres(hand)

      assert result == []
    end

    test "ignore carré de 8" do
      hand = [
        %Card{rank: :eight, suit: :hearts},
        %Card{rank: :eight, suit: :diamonds},
        %Card{rank: :eight, suit: :clubs},
        %Card{rank: :eight, suit: :spades}
      ]

      result = Announcements.detect_carres(hand)

      assert result == []
    end

    test "ignore si seulement 3 cartes identiques" do
      hand = [
        %Card{rank: :jack, suit: :hearts},
        %Card{rank: :jack, suit: :diamonds},
        %Card{rank: :jack, suit: :clubs},
        %Card{rank: :king, suit: :spades}
      ]

      result = Announcements.detect_carres(hand)

      assert result == []
    end
  end

  describe "compare_announcements/2" do
    test "points plus élevés gagnent" do
      all_announcements = [
        %{
          player_position: 0,
          team: {:team, 0},
          announcements: [
            %{type: :tierce, points: 20, cards: [], is_trump: false}
          ]
        },
        %{
          player_position: 1,
          team: {:team, 1},
          announcements: [
            %{type: :cinquante, points: 50, cards: [], is_trump: false}
          ]
        }
      ]

      result = Announcements.compare_announcements(all_announcements, 0)

      assert result.winning_team == {:team, 1}
      assert result.total_points == 50
    end

    test "atout bat non-atout si points égaux" do
      all_announcements = [
        %{
          player_position: 0,
          team: {:team, 0},
          announcements: [
            %{type: :tierce, points: 20, cards: [], is_trump: false}
          ]
        },
        %{
          player_position: 1,
          team: {:team, 1},
          announcements: [
            %{type: :tierce, points: 20, cards: [], is_trump: true}
          ]
        }
      ]

      result = Announcements.compare_announcements(all_announcements, 0)

      assert result.winning_team == {:team, 1}
      assert result.total_points == 20
    end

    test "premier joueur gagne si tout égal" do
      all_announcements = [
        %{
          player_position: 0,
          team: {:team, 0},
          announcements: [
            %{type: :tierce, points: 20, cards: [], is_trump: false}
          ]
        },
        %{
          player_position: 2,
          team: {:team, 0},
          announcements: [
            %{type: :tierce, points: 20, cards: [], is_trump: false}
          ]
        },
        %{
          player_position: 1,
          team: {:team, 1},
          announcements: [
            %{type: :tierce, points: 20, cards: [], is_trump: false}
          ]
        }
      ]

      result = Announcements.compare_announcements(all_announcements, 1)

      assert result.winning_team == {:team, 1}
      assert result.total_points == 20
    end

    test "équipe gagnante marque toutes ses annonces" do
      all_announcements = [
        %{
          player_position: 0,
          team: {:team, 0},
          announcements: [
            %{type: :tierce, points: 20, cards: [], is_trump: false}
          ]
        },
        %{
          player_position: 2,
          team: {:team, 0},
          announcements: [
            %{type: :cinquante, points: 50, cards: [], is_trump: false}
          ]
        },
        %{
          player_position: 1,
          team: {:team, 1},
          announcements: [
            %{type: :tierce, points: 20, cards: [], is_trump: false}
          ]
        }
      ]

      result = Announcements.compare_announcements(all_announcements, 0)

      # Team 0 a la meilleure annonce (cinquante = 50)
      # Team 0 marque toutes ses annonces: 20 + 50 = 70
      assert result.winning_team == {:team, 0}
      assert result.total_points == 70
    end

    test "une seule équipe a des annonces" do
      all_announcements = [
        %{
          player_position: 0,
          team: {:team, 0},
          announcements: [
            %{type: :tierce, points: 20, cards: [], is_trump: false}
          ]
        },
        %{player_position: 1, team: {:team, 1}, announcements: []},
        %{player_position: 2, team: {:team, 0}, announcements: []},
        %{player_position: 3, team: {:team, 1}, announcements: []}
      ]

      result = Announcements.compare_announcements(all_announcements, 0)

      assert result.winning_team == {:team, 0}
      assert result.total_points == 20
    end

    test "aucune équipe n'a d'annonces" do
      all_announcements = [
        %{player_position: 0, team: {:team, 0}, announcements: []},
        %{player_position: 1, team: {:team, 1}, announcements: []},
        %{player_position: 2, team: {:team, 0}, announcements: []},
        %{player_position: 3, team: {:team, 1}, announcements: []}
      ]

      result = Announcements.compare_announcements(all_announcements, 0)

      assert result.winning_team == nil
      assert result.total_points == 0
      assert result.all_announcements == all_announcements
    end
  end

  describe "detect_all/2" do
    test "détecte à la fois séquences et carrés" do
      hand = [
        %Card{rank: :jack, suit: :hearts},
        %Card{rank: :jack, suit: :diamonds},
        %Card{rank: :jack, suit: :clubs},
        %Card{rank: :jack, suit: :spades},
        %Card{rank: :seven, suit: :hearts},
        %Card{rank: :eight, suit: :hearts},
        %Card{rank: :nine, suit: :hearts},
        %Card{rank: :ace, suit: :clubs}
      ]

      result = Announcements.detect_all(hand, :clubs)

      # Devrait avoir un carré de valets et une tierce
      assert length(result) == 2
      types = Enum.map(result, & &1.type) |> Enum.sort()
      assert :carre_jacks in types
      assert :tierce in types
    end

    test "retourne liste vide si aucune annonce" do
      hand = [
        %Card{rank: :seven, suit: :hearts},
        %Card{rank: :nine, suit: :diamonds},
        %Card{rank: :queen, suit: :clubs},
        %Card{rank: :ace, suit: :spades}
      ]

      result = Announcements.detect_all(hand, :clubs)

      assert result == []
    end
  end
end
