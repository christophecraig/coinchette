defmodule Coinchette.Games.Announcements do
  @moduledoc """
  Gère la détection et la comparaison des annonces FFB (Tierce/Cinquante/Cent/Carré).

  Les annonces sont des combinaisons spéciales qui donnent des points bonus :
  - **Séquences** : 3+ cartes consécutives de la même couleur
    - Tierce (3) = 20 points
    - Cinquante (4) = 50 points
    - Cent (5+) = 100 points
  - **Carrés** : 4 cartes identiques
    - Carré de Valets = 200 points
    - Carré de 9 = 150 points
    - Carré d'As/10/Roi/Dame = 100 points chacun
    - Carrés de 7 et 8 ne comptent pas

  ## Règles de comparaison
  1. Meilleure annonce gagne (points plus élevés)
  2. Si égalité : atout > non-atout (séquences seulement)
  3. Si toujours égal : premier joueur gagne
  4. L'équipe gagnante marque TOUTES ses annonces (cumulatif)
  """

  alias Coinchette.Games.Card

  @type announcement :: %{
          type:
            :tierce
            | :cinquante
            | :cent
            | :carre_jacks
            | :carre_nines
            | :carre_aces
            | :carre_tens
            | :carre_kings
            | :carre_queens,
          cards: list(Card.t()),
          points: integer(),
          is_trump: boolean()
        }

  @type player_announcements :: %{
          player_position: integer(),
          team: tuple(),
          announcements: list(announcement())
        }

  @type announcement_result :: %{
          winning_team: tuple() | nil,
          total_points: integer(),
          all_announcements: list(player_announcements())
        }

  @doc """
  Détecte toutes les séquences (Tierce/Cinquante/Cent) dans une main.

  Une séquence est composée de 3 cartes consécutives minimum de la même couleur.
  L'ordre des rangs est : 7 → 8 → 9 → 10 → V → D → R → A

  ## Exemples

      iex> hand = [
      ...>   %Card{rank: :seven, suit: :hearts},
      ...>   %Card{rank: :eight, suit: :hearts},
      ...>   %Card{rank: :nine, suit: :hearts}
      ...> ]
      iex> detect_sequences(hand, :clubs)
      [%{type: :tierce, points: 20, cards: [...], is_trump: false}]
  """
  @spec detect_sequences(list(Card.t()), Card.suit()) :: list(announcement())
  def detect_sequences(hand, trump_suit) do
    hand
    |> Enum.group_by(& &1.suit)
    |> Enum.flat_map(fn {suit, cards} ->
      cards
      |> Enum.sort_by(&rank_order(&1.rank))
      |> find_consecutive_sequences()
      |> Enum.filter(fn seq -> length(seq) >= 3 end)
      |> Enum.map(fn seq ->
        %{
          type: classify_sequence(seq),
          cards: seq,
          points: sequence_points(seq),
          is_trump: suit == trump_suit
        }
      end)
    end)
  end

  @doc """
  Détecte tous les carrés valides dans une main.

  Un carré est composé de 4 cartes identiques.
  Les carrés de 7 et 8 ne comptent pas.

  ## Exemples

      iex> hand = [
      ...>   %Card{rank: :jack, suit: :hearts},
      ...>   %Card{rank: :jack, suit: :diamonds},
      ...>   %Card{rank: :jack, suit: :clubs},
      ...>   %Card{rank: :jack, suit: :spades}
      ...> ]
      iex> detect_carres(hand)
      [%{type: :carre_jacks, points: 200, cards: [...], is_trump: false}]
  """
  @spec detect_carres(list(Card.t())) :: list(announcement())
  def detect_carres(hand) do
    hand
    |> Enum.group_by(& &1.rank)
    |> Enum.filter(fn {rank, cards} ->
      length(cards) == 4 and rank not in [:seven, :eight]
    end)
    |> Enum.map(fn {rank, cards} ->
      %{
        type: classify_carre(rank),
        cards: cards,
        points: carre_points(rank),
        is_trump: false
      }
    end)
  end

  @doc """
  Détecte toutes les annonces (séquences et carrés) dans une main.

  ## Exemples

      iex> hand = [...]
      iex> detect_all(hand, :hearts)
      [%{type: :tierce, ...}, %{type: :carre_jacks, ...}]
  """
  @spec detect_all(list(Card.t()), Card.suit()) :: list(announcement())
  def detect_all(hand, trump_suit) do
    detect_sequences(hand, trump_suit) ++ detect_carres(hand)
  end

  @doc """
  Compare les annonces de tous les joueurs et détermine l'équipe gagnante.

  ## Règles
  1. L'équipe avec la meilleure annonce (points les plus élevés) gagne
  2. En cas d'égalité, une séquence atout bat une séquence non-atout
  3. En cas d'égalité totale, le premier joueur gagne
  4. L'équipe gagnante marque TOUTES ses annonces (cumul)

  ## Exemples

      iex> all_announcements = [
      ...>   %{player_position: 0, team: {:team, 0}, announcements: [...]},
      ...>   %{player_position: 1, team: {:team, 1}, announcements: [...]}
      ...> ]
      iex> compare_announcements(all_announcements, 0)
      %{winning_team: {:team, 0}, total_points: 70, all_announcements: [...]}
  """
  @spec compare_announcements(list(player_announcements()), integer()) :: announcement_result()
  def compare_announcements(all_announcements, first_player_position) do
    # Grouper par équipe et trouver la meilleure annonce de chaque équipe
    team_best =
      all_announcements
      |> Enum.group_by(& &1.team)
      |> Enum.map(fn {team, players} ->
        all_team_announcements = Enum.flat_map(players, & &1.announcements)

        best_announcement =
          if Enum.empty?(all_team_announcements) do
            nil
          else
            Enum.max_by(all_team_announcements, fn ann ->
              {ann.points, if(ann.is_trump, do: 1, else: 0)}
            end)
          end

        first_player_in_team =
          players
          |> Enum.map(& &1.player_position)
          |> Enum.min()

        %{
          team: team,
          best_announcement: best_announcement,
          all_announcements: all_team_announcements,
          first_player: first_player_in_team
        }
      end)
      |> Enum.filter(&(&1.best_announcement != nil))

    # Déterminer l'équipe gagnante
    winning_team_data =
      case team_best do
        [] ->
          nil

        [single_team] ->
          single_team

        teams ->
          Enum.max_by(teams, fn team_data ->
            ann = team_data.best_announcement

            {
              ann.points,
              if(ann.is_trump, do: 1, else: 0),
              # Inverser pour que le premier joueur ait la priorité (plus petit = meilleur)
              -player_priority(team_data.first_player, first_player_position)
            }
          end)
      end

    case winning_team_data do
      nil ->
        %{
          winning_team: nil,
          total_points: 0,
          all_announcements: all_announcements
        }

      team_data ->
        total_points =
          team_data.all_announcements
          |> Enum.map(& &1.points)
          |> Enum.sum()

        %{
          winning_team: team_data.team,
          total_points: total_points,
          all_announcements: all_announcements
        }
    end
  end

  # Helpers privés

  # Ordre des rangs pour les séquences (7 est le plus bas, As le plus haut)
  defp rank_order(:seven), do: 1
  defp rank_order(:eight), do: 2
  defp rank_order(:nine), do: 3
  defp rank_order(:ten), do: 4
  defp rank_order(:jack), do: 5
  defp rank_order(:queen), do: 6
  defp rank_order(:king), do: 7
  defp rank_order(:ace), do: 8

  # Trouve toutes les séquences consécutives maximales dans une liste triée de cartes
  defp find_consecutive_sequences([]), do: []

  defp find_consecutive_sequences(sorted_cards) do
    sorted_cards
    |> Enum.chunk_by(& &1)
    |> Enum.reduce({[], []}, fn [card | _], {sequences, current_seq} ->
      case current_seq do
        [] ->
          {sequences, [card]}

        [last | _] ->
          if rank_order(card.rank) == rank_order(last.rank) + 1 do
            {sequences, [card | current_seq]}
          else
            new_sequences =
              if length(current_seq) >= 3,
                do: [Enum.reverse(current_seq) | sequences],
                else: sequences

            {new_sequences, [card]}
          end
      end
    end)
    |> then(fn {sequences, current_seq} ->
      if length(current_seq) >= 3 do
        [Enum.reverse(current_seq) | sequences]
      else
        sequences
      end
    end)
    |> Enum.reverse()
  end

  # Classifie une séquence selon sa longueur
  defp classify_sequence(cards) do
    case length(cards) do
      3 -> :tierce
      4 -> :cinquante
      n when n >= 5 -> :cent
    end
  end

  # Points pour une séquence
  defp sequence_points(cards) do
    case length(cards) do
      3 -> 20
      4 -> 50
      n when n >= 5 -> 100
    end
  end

  # Classifie un carré selon le rang
  defp classify_carre(:jack), do: :carre_jacks
  defp classify_carre(:nine), do: :carre_nines
  defp classify_carre(:ace), do: :carre_aces
  defp classify_carre(:ten), do: :carre_tens
  defp classify_carre(:king), do: :carre_kings
  defp classify_carre(:queen), do: :carre_queens

  # Points pour un carré
  defp carre_points(:jack), do: 200
  defp carre_points(:nine), do: 150
  defp carre_points(:ace), do: 100
  defp carre_points(:ten), do: 100
  defp carre_points(:king), do: 100
  defp carre_points(:queen), do: 100

  # Calcule la priorité d'un joueur (0 = premier joueur, 1 = deuxième, etc.)
  defp player_priority(player_position, first_player_position) do
    rem(player_position - first_player_position + 4, 4)
  end
end
