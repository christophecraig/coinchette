defmodule Coinchette.Accounts do
  @moduledoc """
  The Accounts context handles user authentication and management.
  """

  import Ecto.Query, warn: false
  alias Coinchette.Repo
  alias Coinchette.Accounts.User
  alias Coinchette.Accounts.UserStats

  @elo_k_factor 32

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    if User.valid_password?(user, password) do
      {:ok, user}
    else
      {:error, :unauthorized}
    end
  end

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Repo.update()
  end

  def confirm_user(%User{} = user) do
    user
    |> User.confirm_changeset()
    |> Repo.update()
  end

  def list_users do
    Repo.all(User)
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  ## User Statistics

  def get_stats(user_id) do
    Repo.get_by(UserStats, user_id: user_id)
  end

  def get_or_create_stats(user_id) do
    case get_stats(user_id) do
      nil ->
        %UserStats{}
        |> UserStats.create_changeset(%{user_id: user_id})
        |> Repo.insert()

      stats ->
        {:ok, stats}
    end
  end

  @doc """
  Records a game result for a user and updates their statistics.

  ## Parameters

    - user_id: The ID of the user
    - result: :win or :loss
    - game_data: Map containing:
      - points_scored: Points the player's team scored
      - points_conceded: Points the opposing team scored
      - had_belote_rebelote: Boolean indicating if the player had Belote/Rebelote
      - team: (optional) 0 or 1 — the player's team
      - is_multiplayer: (optional) boolean — if true, ELO is updated
      - opponent_elo: (optional) average ELO of opposing team
  """
  def record_game_result(user_id, result, game_data)
      when result in [:win, :loss] and is_map(game_data) do
    {:ok, stats} = get_or_create_stats(user_id)

    new_games_played = stats.games_played + 1
    new_games_won = if result == :win, do: stats.games_won + 1, else: stats.games_won
    new_games_lost = if result == :loss, do: stats.games_lost + 1, else: stats.games_lost
    new_total_points_scored = stats.total_points_scored + game_data.points_scored
    new_total_points_conceded = stats.total_points_conceded + game_data.points_conceded
    new_best_score = max(stats.best_score, game_data.points_scored)

    new_belote_count =
      if game_data.had_belote_rebelote,
        do: stats.belote_rebelote_count + 1,
        else: stats.belote_rebelote_count

    # Streak calculation
    {new_current_streak, new_best_streak} = calculate_streaks(stats, result)

    # Team stats
    team = Map.get(game_data, :team)
    team_attrs = calculate_team_stats(stats, team, result)

    # ELO calculation (only for multiplayer games)
    elo_attrs =
      if Map.get(game_data, :is_multiplayer, false) do
        opponent_elo = Map.get(game_data, :opponent_elo, 1000)
        new_elo = calculate_elo(stats.elo_rating, opponent_elo, result)
        %{elo_rating: new_elo}
      else
        %{}
      end

    attrs =
      %{
        games_played: new_games_played,
        games_won: new_games_won,
        games_lost: new_games_lost,
        total_points_scored: new_total_points_scored,
        total_points_conceded: new_total_points_conceded,
        best_score: new_best_score,
        belote_rebelote_count: new_belote_count,
        current_win_streak: new_current_streak,
        best_win_streak: new_best_streak
      }
      |> Map.merge(team_attrs)
      |> Map.merge(elo_attrs)

    stats
    |> UserStats.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Calculates a new ELO rating using the standard formula.
  """
  def calculate_elo(player_elo, opponent_elo, result) do
    expected = 1.0 / (1.0 + :math.pow(10, (opponent_elo - player_elo) / 400.0))
    actual = if result == :win, do: 1.0, else: 0.0
    round(player_elo + @elo_k_factor * (actual - expected))
  end

  defp calculate_streaks(stats, :win) do
    new_streak = stats.current_win_streak + 1
    {new_streak, max(stats.best_win_streak, new_streak)}
  end

  defp calculate_streaks(stats, :loss) do
    {0, stats.best_win_streak}
  end

  defp calculate_team_stats(_stats, nil, _result), do: %{}

  defp calculate_team_stats(stats, 0, result) do
    %{
      games_as_team0: stats.games_as_team0 + 1,
      wins_as_team0: if(result == :win, do: stats.wins_as_team0 + 1, else: stats.wins_as_team0)
    }
  end

  defp calculate_team_stats(stats, 1, result) do
    %{
      games_as_team1: stats.games_as_team1 + 1,
      wins_as_team1: if(result == :win, do: stats.wins_as_team1 + 1, else: stats.wins_as_team1)
    }
  end
end
