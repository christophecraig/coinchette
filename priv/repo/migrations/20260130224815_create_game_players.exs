defmodule Coinchette.Repo.Migrations.CreateGamePlayers do
  use Ecto.Migration

  def change do
    create table(:game_players, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :game_id, references(:games, type: :uuid, on_delete: :delete_all), null: false
      # nullable si bot
      add :user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      # 0-3 (position à la table)
      add :position, :integer, null: false
      add :is_bot, :boolean, default: false, null: false
      # easy, medium, hard (null si humain)
      add :bot_difficulty, :string

      timestamps()
    end

    create index(:game_players, [:game_id])
    create index(:game_players, [:user_id])
    create unique_index(:game_players, [:game_id, :position])
  end
end
