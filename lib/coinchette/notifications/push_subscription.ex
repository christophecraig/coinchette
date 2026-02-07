defmodule Coinchette.Notifications.PushSubscription do
  @moduledoc """
  Schema for storing Web Push API subscriptions.

  Each subscription represents a device/browser where the user has enabled push notifications.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "push_subscriptions" do
    field :endpoint, :string
    field :auth, :string
    field :p256dh, :string
    field :user_agent, :string
    field :active, :boolean, default: true

    # Notification preferences
    field :notify_game_invite, :boolean, default: true
    field :notify_your_turn, :boolean, default: true
    field :notify_game_result, :boolean, default: true
    field :notify_chat_message, :boolean, default: false
    field :notify_friend_request, :boolean, default: true

    belongs_to :user, Coinchette.Accounts.User, type: :binary_id

    timestamps()
  end

  @doc """
  Changeset for creating a new push subscription.
  """
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :user_id,
      :endpoint,
      :auth,
      :p256dh,
      :user_agent,
      :active,
      :notify_game_invite,
      :notify_your_turn,
      :notify_game_result,
      :notify_chat_message,
      :notify_friend_request
    ])
    |> validate_required([:user_id, :endpoint, :auth, :p256dh])
    |> unique_constraint(:endpoint)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for updating notification preferences.
  """
  def preferences_changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :notify_game_invite,
      :notify_your_turn,
      :notify_game_result,
      :notify_chat_message,
      :notify_friend_request,
      :active
    ])
  end
end
