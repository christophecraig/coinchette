defmodule Coinchette.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :game_id, references(:games, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :uuid)
      add :message, :text, null: false
      add :message_type, :string, default: "user", null: false  # "user", "system"
      timestamps(updated_at: false)
    end

    create index(:chat_messages, [:game_id])
    create index(:chat_messages, [:game_id, :inserted_at])
  end
end
