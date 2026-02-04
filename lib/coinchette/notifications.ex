defmodule Coinchette.Notifications do
  @moduledoc """
  The Notifications context for managing push notifications.
  """

  import Ecto.Query, warn: false
  alias Coinchette.Repo
  alias Coinchette.Notifications.PushSubscription

  @doc """
  Subscribe a user to push notifications.

  ## Parameters
    - user_id: The ID of the user subscribing
    - subscription_data: Map containing endpoint, keys (auth, p256dh), and optional user_agent

  ## Examples

      iex> subscribe_user(1, %{
      ...>   "endpoint" => "https://...",
      ...>   "keys" => %{"auth" => "...", "p256dh" => "..."}
      ...> })
      {:ok, %PushSubscription{}}
  """
  def subscribe_user(user_id, subscription_data) do
    attrs = %{
      user_id: user_id,
      endpoint: subscription_data["endpoint"],
      auth: subscription_data["keys"]["auth"],
      p256dh: subscription_data["keys"]["p256dh"],
      user_agent: subscription_data["user_agent"]
    }

    %PushSubscription{}
    |> PushSubscription.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:auth, :p256dh, :user_agent, :updated_at]},
      conflict_target: :endpoint
    )
  end

  @doc """
  Unsubscribe a user from push notifications by endpoint.
  """
  def unsubscribe_user(user_id, endpoint) do
    from(s in PushSubscription,
      where: s.user_id == ^user_id and s.endpoint == ^endpoint
    )
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Get all active subscriptions for a user.
  """
  def list_user_subscriptions(user_id) do
    from(s in PushSubscription,
      where: s.user_id == ^user_id and s.active == true,
      order_by: [desc: s.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Update notification preferences for a subscription.
  """
  def update_preferences(subscription_id, user_id, attrs) do
    case Repo.get_by(PushSubscription, id: subscription_id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      subscription ->
        subscription
        |> PushSubscription.preferences_changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Mark a subscription as inactive (for failed deliveries).
  """
  def deactivate_subscription(subscription_id) do
    case Repo.get(PushSubscription, subscription_id) do
      nil ->
        {:error, :not_found}

      subscription ->
        subscription
        |> PushSubscription.preferences_changeset(%{active: false})
        |> Repo.update()
    end
  end

  @doc """
  Send a push notification to a user.

  ## Notification types:
    - :game_invite - Someone invited you to a game
    - :your_turn - It's your turn to play
    - :game_result - Game finished
    - :chat_message - New chat message (if enabled)

  ## Examples

      iex> send_notification(user_id, :your_turn, %{
      ...>   title: "Your turn!",
      ...>   body: "Play against Alice",
      ...>   game_id: 123
      ...> })
      {:ok, 2}  # Number of successful deliveries
  """
  def send_notification(user_id, notification_type, payload) do
    subscriptions = get_subscriptions_for_notification(user_id, notification_type)

    results =
      subscriptions
      |> Enum.map(fn subscription ->
        send_push(subscription, payload)
      end)

    successful = Enum.count(results, fn {status, _} -> status == :ok end)
    {:ok, successful}
  end

  @doc """
  Send a push notification to multiple users.
  """
  def broadcast_notification(user_ids, notification_type, payload) do
    user_ids
    |> Enum.map(fn user_id ->
      send_notification(user_id, notification_type, payload)
    end)
    |> Enum.reduce(0, fn {:ok, count}, acc -> acc + count end)
  end

  # Private functions

  defp get_subscriptions_for_notification(user_id, notification_type) do
    query =
      from(s in PushSubscription,
        where: s.user_id == ^user_id and s.active == true
      )

    query =
      case notification_type do
        :game_invite -> from(s in query, where: s.notify_game_invite == true)
        :your_turn -> from(s in query, where: s.notify_your_turn == true)
        :game_result -> from(s in query, where: s.notify_game_result == true)
        :chat_message -> from(s in query, where: s.notify_chat_message == true)
        _ -> query
      end

    Repo.all(query)
  end

  defp send_push(subscription, payload) do
    vapid_details = get_vapid_details()

    web_push_payload = Jason.encode!(payload)

    subscription_info = %{
      endpoint: subscription.endpoint,
      keys: %{
        auth: subscription.auth,
        p256dh: subscription.p256dh
      }
    }

    result =
      WebPushEncryption.send_web_push(
        web_push_payload,
        subscription_info,
        vapid_details
      )

    case result do
      {:ok, _response} ->
        {:ok, :sent}

      {:error, %{status_code: status}} when status in [404, 410] ->
        # Subscription no longer valid
        deactivate_subscription(subscription.id)
        {:error, :subscription_expired}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_vapid_details do
    %{
      subject: Application.get_env(:coinchette, :vapid_subject),
      public_key: Application.get_env(:coinchette, :vapid_public_key),
      private_key: Application.get_env(:coinchette, :vapid_private_key)
    }
  end
end
