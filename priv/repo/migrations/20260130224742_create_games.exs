defmodule Coinchette.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games, primary_key: false) do
      add :id, :uuid, primary_key: true
      # belote, coinche
      add :variant, :string, null: false
      # solo, multi
      add :mode, :string, null: false
      # waiting, playing, finished
      add :status, :string, null: false
      # JSONB - game state complet
      add :state, :map
      # 0 ou 1
      add :winner_team, :integer
      # JSONB - scores par équipe
      add :scores, :map
      add :started_at, :naive_datetime
      add :finished_at, :naive_datetime

      timestamps()
    end

    create index(:games, [:status])
    create index(:games, [:variant])
  end
end
