defmodule Coinchette.Repo.Migrations.CreateGameEvents do
  use Ecto.Migration

  def change do
    create table(:game_events, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :game_id, references(:games, type: :uuid, on_delete: :delete_all), null: false
      # "card_played", "bid_made", etc.
      add :event_type, :string, null: false
      add :player_id, references(:users, type: :uuid)
      # JSONB event data
      add :data, :map
      # Order within game
      add :sequence, :integer, null: false
      timestamps(updated_at: false)
    end

    create index(:game_events, [:game_id])
    create index(:game_events, [:game_id, :sequence])
  end
end
