defmodule Coinchette.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :variant, :string, null: false  # belote, coinche
      add :mode, :string, null: false     # solo, multi
      add :status, :string, null: false   # waiting, playing, finished
      add :state, :map                    # JSONB - game state complet
      add :winner_team, :integer          # 0 ou 1
      add :scores, :map                   # JSONB - scores par équipe
      add :started_at, :naive_datetime
      add :finished_at, :naive_datetime

      timestamps()
    end

    create index(:games, [:status])
    create index(:games, [:variant])
  end
end
