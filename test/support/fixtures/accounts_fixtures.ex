defmodule Coinchette.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Coinchette.Accounts` context.
  """

  @doc """
  Generate a unique user email.
  """
  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"

  @doc """
  Generate a unique user username.
  """
  def unique_user_username, do: "user#{System.unique_integer([:positive])}"

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: unique_user_email(),
        username: unique_user_username(),
        password: "password123"
      })
      |> Coinchette.Accounts.register_user()

    user
  end

  @doc """
  Generate a user and return with plaintext password for testing.
  """
  def user_with_password_fixture(attrs \\ %{}) do
    password = attrs[:password] || "password123"
    user = user_fixture(attrs)
    {user, password}
  end

  @doc """
  Generate a user with statistics initialized.
  """
  def user_with_stats_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)
    {:ok, _stats} = Coinchette.Accounts.get_or_create_stats(user.id)
    user
  end

  @doc """
  Generate a user with game results for testing profile/stats pages.

  ## Options

    * `:wins` - Number of wins to record (default: 0)
    * `:losses` - Number of losses to record (default: 0)
    * `:belote_count` - Number of belote/rebelote announcements (default: 0)

  ## Examples

      user = user_with_game_results_fixture(wins: 5, losses: 2)

  """
  def user_with_game_results_fixture(opts \\ []) do
    user = user_with_stats_fixture()

    wins = Keyword.get(opts, :wins, 0)
    losses = Keyword.get(opts, :losses, 0)
    belote_count = Keyword.get(opts, :belote_count, 0)

    # Record wins
    for _ <- 1..wins do
      Coinchette.Accounts.record_game_result(user.id, :win, %{
        points_scored: Enum.random(100..162),
        points_conceded: Enum.random(0..80),
        had_belote_rebelote: false
      })
    end

    # Record losses
    for _ <- 1..losses do
      Coinchette.Accounts.record_game_result(user.id, :loss, %{
        points_scored: Enum.random(0..80),
        points_conceded: Enum.random(100..162),
        had_belote_rebelote: false
      })
    end

    # Add belote announcements to some wins
    for _ <- 1..min(belote_count, wins) do
      Coinchette.Accounts.record_game_result(user.id, :win, %{
        points_scored: Enum.random(100..162),
        points_conceded: Enum.random(0..80),
        had_belote_rebelote: true
      })
    end

    # Reload user to get updated stats
    Coinchette.Repo.get!(Coinchette.Accounts.User, user.id)
    |> Coinchette.Repo.preload(:user_stats, force: true)
  end

  @doc """
  Generate multiple users at once.

  ## Examples

      [user1, user2, user3] = users_fixture(3)
      [alice, bob] = users_fixture(2, fn i -> %{username: "user_\#{i}"} end)

  """
  def users_fixture(count, attrs_fn \\ fn _i -> %{} end) do
    for i <- 1..count do
      user_fixture(attrs_fn.(i))
    end
  end
end
