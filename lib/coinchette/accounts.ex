defmodule Coinchette.Accounts do
  @moduledoc """
  The Accounts context handles user authentication and management.
  """

  import Ecto.Query, warn: false
  alias Coinchette.Repo
  alias Coinchette.Accounts.User
  alias Coinchette.Accounts.UserStats

  @doc """
  Gets a single user by ID.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("user@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("user@example.com", "correct_password")
      {:ok, %User{}}

      iex> get_user_by_email_and_password("user@example.com", "wrong_password")
      {:error, :unauthorized}

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    if User.valid_password?(user, password) do
      {:ok, user}
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Registers a new user.

  ## Examples

      iex> register_user(%{email: "user@example.com", username: "user", password: "secret123"})
      {:ok, %User{}}

      iex> register_user(%{email: "bad"})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user's password.

  ## Examples

      iex> update_user_password(user, %{password: "new_password"})
      {:ok, %User{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Confirms a user's account.

  ## Examples

      iex> confirm_user(user)
      {:ok, %User{}}

  """
  def confirm_user(%User{} = user) do
    user
    |> User.confirm_changeset()
    |> Repo.update()
  end

  @doc """
  Lists all users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  ## User Statistics

  @doc """
  Gets user statistics by user ID.

  Returns nil if the user has no statistics yet.

  ## Examples

      iex> get_stats(user_id)
      %UserStats{}

      iex> get_stats(unknown_id)
      nil

  """
  def get_stats(user_id) do
    Repo.get_by(UserStats, user_id: user_id)
  end

  @doc """
  Gets or creates user statistics.

  If the user doesn't have statistics yet, creates a new record with default values.

  ## Examples

      iex> get_or_create_stats(user_id)
      {:ok, %UserStats{}}

  """
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

  ## Examples

      iex> record_game_result(user_id, :win, %{points_scored: 120, points_conceded: 42, had_belote_rebelote: true})
      {:ok, %UserStats{}}

  """
  def record_game_result(user_id, result, game_data)
      when result in [:win, :loss] and is_map(game_data) do
    {:ok, stats} = get_or_create_stats(user_id)

    # Calculate new values
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

    # Update stats
    stats
    |> UserStats.update_changeset(%{
      games_played: new_games_played,
      games_won: new_games_won,
      games_lost: new_games_lost,
      total_points_scored: new_total_points_scored,
      total_points_conceded: new_total_points_conceded,
      best_score: new_best_score,
      belote_rebelote_count: new_belote_count
    })
    |> Repo.update()
  end
end
