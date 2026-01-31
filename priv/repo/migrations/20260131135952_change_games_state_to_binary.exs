defmodule Coinchette.Repo.Migrations.ChangeGamesStateToBinary do
  use Ecto.Migration

  def up do
    # Clear existing state data and change column type
    execute "ALTER TABLE games DROP COLUMN state"
    execute "ALTER TABLE games ADD COLUMN state bytea"
  end

  def down do
    # Reverse: drop bytea column and recreate as jsonb
    execute "ALTER TABLE games DROP COLUMN state"
    execute "ALTER TABLE games ADD COLUMN state jsonb"
  end
end
