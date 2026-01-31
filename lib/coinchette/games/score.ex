defmodule Coinchette.Games.Score do
  @moduledoc """
  Gère le calcul des points selon les règles officielles FFB.

  Points par manche:
  - Total: 162 points
  - Dix de der: +10 points au gagnant du dernier pli

  Valeurs cartes ATOUT:
  - Valet: 20, 9: 14, As: 11, 10: 10, Roi: 4, Dame: 3, 8: 0, 7: 0

  Valeurs cartes NON-ATOUT:
  - As: 11, 10: 10, Roi: 4, Dame: 3, Valet: 2, 9/8/7: 0
  """

  alias Coinchette.Games.{Card, Trick}

  @dix_de_der 10

  @doc """
  Calcule les points d'un pli selon les valeurs FFB.

  ## Exemples

      iex> trick = Trick.new()
      iex> trick = Trick.add_card(trick, Card.new(:ace, :hearts), 0)
      iex> trick = Trick.add_card(trick, Card.new(:ten, :hearts), 1)
      iex> Score.trick_points(trick, :spades)
      21  # As=11 + 10=10 (non-trump)
  """
  def trick_points(%Trick{cards: cards}, trump_suit) do
    cards
    |> Enum.map(fn {card, _position} -> Card.value(card, trump_suit) end)
    |> Enum.sum()
  end

  @doc """
  Calcule les scores totaux de chaque équipe à partir des plis gagnés.

  ## Paramètres

    * `tricks_won` - Liste de tuples {team, trick}
    * `trump_suit` - La couleur d'atout
    * `opts` - Options:
      * `:last_trick_winner` - Équipe qui a gagné le dernier pli (reçoit +10)
      * `:belote_rebelote` - Tuple {team, true} si une équipe a Belote/Rebelote (+20)

  ## Exemples

      iex> tricks_won = [{0, trick1}, {1, trick2}, {0, trick3}]
      iex> scores = Score.calculate_scores(tricks_won, :hearts, last_trick_winner: 0)
      iex> scores[0] + scores[1]
      162  # Total toujours 162
  """
  def calculate_scores(tricks_won, trump_suit, opts \\ []) do
    last_trick_winner = Keyword.get(opts, :last_trick_winner)
    belote_rebelote = Keyword.get(opts, :belote_rebelote)

    # Calculer les points de base par équipe
    base_scores =
      tricks_won
      |> Enum.group_by(fn {team, _trick} -> team end, fn {_team, trick} -> trick end)
      |> Enum.map(fn {team, tricks} ->
        points =
          tricks
          |> Enum.map(&trick_points(&1, trump_suit))
          |> Enum.sum()

        {team, points}
      end)
      |> Map.new()

    # Ajouter le dix de der si spécifié
    scores_with_dix_de_der =
      if last_trick_winner do
        Map.update(base_scores, last_trick_winner, @dix_de_der, &(&1 + @dix_de_der))
      else
        base_scores
      end

    # Ajouter Belote/Rebelote si spécifié
    scores_with_belote =
      case belote_rebelote do
        {team, true} ->
          Map.update(scores_with_dix_de_der, team, 20, &(&1 + 20))

        _ ->
          scores_with_dix_de_der
      end

    scores_with_belote
    |> ensure_both_teams()
  end

  @doc """
  Calcule les scores finaux d'une partie complète.

  Retourne un tuple avec:
  - Scores par équipe
  - Équipe gagnante
  - Détails (plis, dix de der, etc.)

  ## Exemples

      iex> game = %Game{tricks_won: [...], trump_suit: :hearts}
      iex> {scores, winner, details} = Score.final_scores(game)
  """
  def final_scores(game) do
    last_trick_winner =
      case List.last(game.tricks_won) do
        {team, _trick} -> team
        nil -> nil
      end

    scores = calculate_scores(game.tricks_won, game.trump_suit, last_trick_winner: last_trick_winner)

    winner =
      scores
      |> Enum.max_by(fn {_team, points} -> points end)
      |> elem(0)

    details = %{
      total_points: 162,
      dix_de_der_winner: last_trick_winner,
      tricks_count: %{
        0 => count_team_tricks(game.tricks_won, 0),
        1 => count_team_tricks(game.tricks_won, 1)
      }
    }

    {scores, winner, details}
  end

  # Assure que les deux équipes sont présentes dans la map (avec 0 si absente)
  defp ensure_both_teams(scores) do
    scores
    |> Map.put_new(0, 0)
    |> Map.put_new(1, 0)
  end

  # Compte le nombre de plis gagnés par une équipe
  defp count_team_tricks(tricks_won, team) do
    Enum.count(tricks_won, fn {t, _trick} -> t == team end)
  end
end
