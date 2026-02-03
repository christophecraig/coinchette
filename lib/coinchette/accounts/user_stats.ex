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

    timestamps()
  end

  @doc """
  Changeset for creating initial user stats.
  """
  def create_changeset(user_stats, attrs) do
    user_stats
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end

  @doc """
  Changeset for updating user stats after a game.
  """
  def update_changeset(user_stats, attrs) do
    user_stats
    |> cast(attrs, [
      :games_played,
      :games_won,
      :games_lost,
      :total_points_scored,
      :total_points_conceded,
      :best_score,
      :belote_rebelote_count
    ])
    |> validate_number(:games_played, greater_than_or_equal_to: 0)
    |> validate_number(:games_won, greater_than_or_equal_to: 0)
    |> validate_number(:games_lost, greater_than_or_equal_to: 0)
    |> validate_number(:total_points_scored, greater_than_or_equal_to: 0)
    |> validate_number(:total_points_conceded, greater_than_or_equal_to: 0)
    |> validate_number(:best_score, greater_than_or_equal_to: 0)
    |> validate_number(:belote_rebelote_count, greater_than_or_equal_to: 0)
  end

  @doc """
  Calculates the win rate as a percentage.
  """
  def win_rate(%__MODULE__{games_played: 0}), do: 0.0

  def win_rate(%__MODULE__{games_played: games_played, games_won: games_won}) do
    Float.round(games_won / games_played * 100, 2)
  end

  @doc """
  Calculates the average points scored per game.
  """
  def average_points_scored(%__MODULE__{games_played: 0}), do: 0.0

  def average_points_scored(%__MODULE__{games_played: games_played, total_points_scored: total}) do
    Float.round(total / games_played, 2)
  end

  @doc """
  Calculates the average points conceded per game.
  """
  def average_points_conceded(%__MODULE__{games_played: 0}), do: 0.0

  def average_points_conceded(%__MODULE__{
        games_played: games_played,
        total_points_conceded: total
      }) do
    Float.round(total / games_played, 2)
  end
end
