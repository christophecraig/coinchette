defmodule Coinchette.Repo.Migrations.AddMultiRoundSupportToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      # Target score for the game (500 or 1000 points)
      add :target_score, :integer, default: 1000

      # Current round number (increments after each hand)
      add :round_number, :integer, default: 1
    end
  end
end
