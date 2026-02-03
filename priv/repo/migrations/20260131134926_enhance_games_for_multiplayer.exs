defmodule Coinchette.Repo.Migrations.EnhanceGamesForMultiplayer do
  use Ecto.Migration

  def change do
    alter table(:games) do
      # 6-char invite code (ABC123)
      add :room_code, :string
      add :creator_id, references(:users, type: :uuid)
      add :is_private, :boolean, default: true
      add :max_players, :integer, default: 4
      add :current_turn_player_id, references(:users, type: :uuid)
      # Optimistic locking
      add :version, :integer, default: 0
    end

    create unique_index(:games, [:room_code])
    create index(:games, [:creator_id])
    create index(:games, [:current_turn_player_id])
  end
end
