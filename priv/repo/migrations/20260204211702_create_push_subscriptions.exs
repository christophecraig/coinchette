defmodule Coinchette.Repo.Migrations.CreatePushSubscriptions do
  use Ecto.Migration

  def change do
    create table(:push_subscriptions) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :endpoint, :text, null: false
      add :auth, :string, null: false
      add :p256dh, :string, null: false
      add :user_agent, :string
      add :active, :boolean, default: true, null: false

      # Notification preferences
      add :notify_game_invite, :boolean, default: true, null: false
      add :notify_your_turn, :boolean, default: true, null: false
      add :notify_game_result, :boolean, default: true, null: false
      add :notify_chat_message, :boolean, default: false, null: false

      timestamps()
    end

    create index(:push_subscriptions, [:user_id])
    create unique_index(:push_subscriptions, [:endpoint])
  end
end
