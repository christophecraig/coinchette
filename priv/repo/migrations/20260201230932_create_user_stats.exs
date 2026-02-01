defmodule Coinchette.Repo.Migrations.CreateUserStats do
  use Ecto.Migration

  def change do
    create table(:user_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Game statistics
      add :games_played, :integer, default: 0, null: false
      add :games_won, :integer, default: 0, null: false
      add :games_lost, :integer, default: 0, null: false

      # Points statistics
      add :total_points_scored, :integer, default: 0, null: false
      add :total_points_conceded, :integer, default: 0, null: false
      add :best_score, :integer, default: 0, null: false

      # Special achievements
      add :belote_rebelote_count, :integer, default: 0, null: false

      timestamps()
    end

    create unique_index(:user_stats, [:user_id])
  end
end
