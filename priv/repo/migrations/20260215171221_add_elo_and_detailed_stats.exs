defmodule Coinchette.Repo.Migrations.AddEloAndDetailedStats do
  use Ecto.Migration

  def change do
    alter table(:user_stats) do
      add :elo_rating, :integer, default: 1000, null: false
      add :current_win_streak, :integer, default: 0, null: false
      add :best_win_streak, :integer, default: 0, null: false
      add :games_as_team0, :integer, default: 0, null: false
      add :games_as_team1, :integer, default: 0, null: false
      add :wins_as_team0, :integer, default: 0, null: false
      add :wins_as_team1, :integer, default: 0, null: false
    end
  end
end
