defmodule Coinchette.Accounts.UserStats do
  @moduledoc """
  User statistics schema for tracking player performance.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Coinchette.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_stats" do
    belongs_to :user, User

    # Game statistics
    field :games_played, :integer, default: 0
    field :games_won, :integer, default: 0
    field :games_lost, :integer, default: 0

    # Points statistics
    field :total_points_scored, :integer, default: 0
    field :total_points_conceded, :integer, default: 0
    field :best_score, :integer, default: 0

    # Special achievements
    field :belote_rebelote_count, :integer, default: 0

    # ELO rating
    field :elo_rating, :integer, default: 1000

    # Streaks
    field :current_win_streak, :integer, default: 0
    field :best_win_streak, :integer, default: 0

    # Team stats
    field :games_as_team0, :integer, default: 0
    field :games_as_team1, :integer, default: 0
    field :wins_as_team0, :integer, default: 0
    field :wins_as_team1, :integer, default: 0

    timestamps()
  end

  @update_fields [
    :games_played,
    :games_won,
    :games_lost,
    :total_points_scored,
    :total_points_conceded,
    :best_score,
    :belote_rebelote_count,
    :elo_rating,
    :current_win_streak,
    :best_win_streak,
    :games_as_team0,
    :games_as_team1,
    :wins_as_team0,
    :wins_as_team1
  ]

  def create_changeset(user_stats, attrs) do
    user_stats
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end

  def update_changeset(user_stats, attrs) do
    user_stats
    |> cast(attrs, @update_fields)
    |> validate_number(:games_played, greater_than_or_equal_to: 0)
    |> validate_number(:games_won, greater_than_or_equal_to: 0)
    |> validate_number(:games_lost, greater_than_or_equal_to: 0)
    |> validate_number(:total_points_scored, greater_than_or_equal_to: 0)
    |> validate_number(:total_points_conceded, greater_than_or_equal_to: 0)
    |> validate_number(:best_score, greater_than_or_equal_to: 0)
    |> validate_number(:belote_rebelote_count, greater_than_or_equal_to: 0)
    |> validate_number(:elo_rating, greater_than_or_equal_to: 0)
  end

  def win_rate(%__MODULE__{games_played: 0}), do: 0.0

  def win_rate(%__MODULE__{games_played: games_played, games_won: games_won}) do
    Float.round(games_won / games_played * 100, 2)
  end

  def average_points_scored(%__MODULE__{games_played: 0}), do: 0.0

  def average_points_scored(%__MODULE__{games_played: games_played, total_points_scored: total}) do
    Float.round(total / games_played, 2)
  end

  def average_points_conceded(%__MODULE__{games_played: 0}), do: 0.0

  def average_points_conceded(%__MODULE__{
        games_played: games_played,
        total_points_conceded: total
      }) do
    Float.round(total / games_played, 2)
  end

  @doc """
  Returns the ELO rank label based on rating.
  """
  def elo_rank(elo) when elo < 800, do: "Débutant"
  def elo_rank(elo) when elo < 1000, do: "Apprenti"
  def elo_rank(elo) when elo < 1200, do: "Joueur"
  def elo_rank(elo) when elo < 1400, do: "Confirmé"
  def elo_rank(elo) when elo < 1600, do: "Expert"
  def elo_rank(_elo), do: "Maître"

  @doc """
  Returns the CSS color class for an ELO rating.
  """
  def elo_color(elo) when elo < 800, do: "text-base-content/60"
  def elo_color(elo) when elo < 1000, do: "text-info"
  def elo_color(elo) when elo < 1200, do: "text-success"
  def elo_color(elo) when elo < 1400, do: "text-warning"
  def elo_color(elo) when elo < 1600, do: "text-error"
  def elo_color(_elo), do: "text-secondary"

  def team_win_rate(_stats, _team, 0), do: 0.0

  def team_win_rate(stats, 0, _games) do
    Float.round(stats.wins_as_team0 / stats.games_as_team0 * 100, 2)
  end

  def team_win_rate(stats, 1, _games) do
    Float.round(stats.wins_as_team1 / stats.games_as_team1 * 100, 2)
  end
end
