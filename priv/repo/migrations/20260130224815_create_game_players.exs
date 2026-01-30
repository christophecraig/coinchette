defmodule Coinchette.Repo.Migrations.CreateGamePlayers do
  use Ecto.Migration

  def change do
    create table(:game_players, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :game_id, references(:games, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :uuid, on_delete: :nilify_all)  # nullable si bot
      add :position, :integer, null: false  # 0-3 (position à la table)
      add :is_bot, :boolean, default: false, null: false
      add :bot_difficulty, :string  # easy, medium, hard (null si humain)

      timestamps()
    end

    create index(:game_players, [:game_id])
    create index(:game_players, [:user_id])
    create unique_index(:game_players, [:game_id, :position])
  end
end
