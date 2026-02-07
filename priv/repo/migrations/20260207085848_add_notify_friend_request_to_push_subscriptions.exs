defmodule Coinchette.Repo.Migrations.AddNotifyFriendRequestToPushSubscriptions do
  use Ecto.Migration

  def change do
    alter table(:push_subscriptions) do
      add :notify_friend_request, :boolean, default: true, null: false
    end
  end
end
