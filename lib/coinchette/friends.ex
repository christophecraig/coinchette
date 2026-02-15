defmodule Coinchette.Friends do
  @moduledoc """
  The Friends context for managing friendships between users.
  """

  import Ecto.Query, warn: false
  alias Coinchette.Repo
  alias Coinchette.Friends.Friendship
  alias Coinchette.Accounts.User
  alias Coinchette.Notifications.FriendNotifications

  @doc """
  Sends a friend request from one user to another by username.

  Creates two bidirectional rows (from->to and to->from) both with
  `initiated_by` set to the sender. Broadcasts to the recipient via PubSub.
  """
  def send_friend_request(from_user_id, to_username) do
    with {:ok, to_user} <- find_user_by_username(to_username),
         :ok <- validate_not_self(from_user_id, to_user.id),
         :ok <- validate_no_existing_friendship(from_user_id, to_user.id) do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      rows = [
        %{
          id: Ecto.UUID.generate(),
          user_id: from_user_id,
          friend_id: to_user.id,
          status: "pending",
          initiated_by: from_user_id,
          inserted_at: now,
          updated_at: now
        },
        %{
          id: Ecto.UUID.generate(),
          user_id: to_user.id,
          friend_id: from_user_id,
          status: "pending",
          initiated_by: from_user_id,
          inserted_at: now,
          updated_at: now
        }
      ]

      {2, _} = Repo.insert_all(Friendship, rows)

      # Broadcast to recipient
      Phoenix.PubSub.broadcast(
        Coinchette.PubSub,
        "user:#{to_user.id}:friends",
        {:friend_request_received, %{from_user_id: from_user_id}}
      )

      # Send push notification
      from_user = Repo.get!(User, from_user_id)
      FriendNotifications.notify_friend_request(to_user.id, from_user.username)

      {:ok, to_user}
    end
  end

  @doc """
  Accepts a pending friend request.
  Updates both bidirectional rows to "accepted".
  """
  def accept_friend_request(user_id, friend_id) do
    Repo.transaction(fn ->
      {count, _} =
        from(f in Friendship,
          where:
            (f.user_id == ^user_id and f.friend_id == ^friend_id) or
              (f.user_id == ^friend_id and f.friend_id == ^user_id),
          where: f.status == "pending",
          where: f.initiated_by == ^friend_id
        )
        |> Repo.update_all(set: [status: "accepted", updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)])

      if count == 2 do
        broadcast_friend_event(user_id, {:friend_request_accepted, %{friend_id: friend_id}})
        broadcast_friend_event(friend_id, {:friend_request_accepted, %{friend_id: user_id}})

        # Send push notification to the original requester
        acceptor = Repo.get!(User, user_id)
        FriendNotifications.notify_friend_accepted(friend_id, acceptor.username)

        :ok
      else
        Repo.rollback(:not_found)
      end
    end)
  end

  @doc """
  Declines a pending friend request.
  Updates both bidirectional rows to "declined".
  """
  def decline_friend_request(user_id, friend_id) do
    {count, _} =
      from(f in Friendship,
        where:
          (f.user_id == ^user_id and f.friend_id == ^friend_id) or
            (f.user_id == ^friend_id and f.friend_id == ^user_id),
        where: f.status == "pending",
        where: f.initiated_by == ^friend_id
      )
      |> Repo.update_all(set: [status: "declined", updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)])

    if count == 2, do: :ok, else: {:error, :not_found}
  end

  @doc """
  Cancels an outgoing friend request (deletes both rows).
  """
  def cancel_friend_request(user_id, friend_id) do
    {count, _} =
      from(f in Friendship,
        where:
          (f.user_id == ^user_id and f.friend_id == ^friend_id) or
            (f.user_id == ^friend_id and f.friend_id == ^user_id),
        where: f.status == "pending",
        where: f.initiated_by == ^user_id
      )
      |> Repo.delete_all()

    if count == 2, do: :ok, else: {:error, :not_found}
  end

  @doc """
  Removes a friendship (deletes both rows).
  """
  def remove_friend(user_id, friend_id) do
    {count, _} =
      from(f in Friendship,
        where:
          (f.user_id == ^user_id and f.friend_id == ^friend_id) or
            (f.user_id == ^friend_id and f.friend_id == ^user_id)
      )
      |> Repo.delete_all()

    if count == 2 do
      broadcast_friend_event(user_id, {:friend_removed, %{friend_id: friend_id}})
      broadcast_friend_event(friend_id, {:friend_removed, %{friend_id: user_id}})
      :ok
    else
      {:error, :not_found}
    end
  end

  @doc """
  Lists accepted friends for a user, preloading the friend user.
  """
  def list_friends(user_id) do
    from(f in Friendship,
      where: f.user_id == ^user_id and f.status == "accepted",
      join: u in User,
      on: u.id == f.friend_id,
      select: %{id: f.id, friend_id: f.friend_id, username: u.username},
      order_by: u.username
    )
    |> Repo.all()
  end

  @doc """
  Lists received pending friend requests (where someone else initiated).
  """
  def list_pending_requests(user_id) do
    from(f in Friendship,
      where: f.user_id == ^user_id and f.status == "pending" and f.initiated_by != ^user_id,
      join: u in User,
      on: u.id == f.friend_id,
      select: %{id: f.id, friend_id: f.friend_id, username: u.username, inserted_at: f.inserted_at},
      order_by: [desc: f.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists sent pending friend requests (where the user initiated).
  """
  def list_sent_requests(user_id) do
    from(f in Friendship,
      where: f.user_id == ^user_id and f.status == "pending" and f.initiated_by == ^user_id,
      join: u in User,
      on: u.id == f.friend_id,
      select: %{id: f.id, friend_id: f.friend_id, username: u.username, inserted_at: f.inserted_at},
      order_by: [desc: f.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns the friendship status between two users, or nil if none exists.
  """
  def friendship_status(user_id, other_user_id) do
    from(f in Friendship,
      where: f.user_id == ^user_id and f.friend_id == ^other_user_id,
      select: f.status
    )
    |> Repo.one()
  end

  @doc """
  Searches users by username, excluding self and existing friendships.
  """
  def search_users(current_user_id, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    search_term = "%#{query}%"

    existing_friend_ids =
      from(f in Friendship,
        where: f.user_id == ^current_user_id,
        select: f.friend_id
      )

    from(u in User,
      where: u.id != ^current_user_id,
      where: ilike(u.username, ^search_term),
      where: u.id not in subquery(existing_friend_ids),
      select: %{id: u.id, username: u.username},
      order_by: u.username,
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Returns a set of friend IDs that are currently online.
  """
  def online_friend_ids(user_id) do
    friend_ids =
      list_friends(user_id)
      |> Enum.map(& &1.friend_id)
      |> MapSet.new()

    online_ids =
      CoinchetteWeb.Presence.list("users:online")
      |> Map.keys()
      |> MapSet.new()

    MapSet.intersection(friend_ids, online_ids)
  end

  @doc """
  Lists accepted friends with their stats, sorted by ELO descending.
  Returns a list of maps with :friend_id, :username, :elo_rating, :games_played, :games_won.
  """
  def list_friends_with_stats(user_id) do
    alias Coinchette.Accounts.UserStats

    from(f in Friendship,
      where: f.user_id == ^user_id and f.status == "accepted",
      join: u in User, on: u.id == f.friend_id,
      left_join: s in UserStats, on: s.user_id == u.id,
      select: %{
        friend_id: u.id,
        username: u.username,
        elo_rating: coalesce(s.elo_rating, 1000),
        games_played: coalesce(s.games_played, 0),
        games_won: coalesce(s.games_won, 0)
      },
      order_by: [desc: coalesce(s.elo_rating, 1000)]
    )
    |> Repo.all()
  end

  # Private helpers

  defp find_user_by_username(username) do
    case Repo.get_by(User, username: username) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  defp validate_not_self(user_id, other_id) do
    if user_id == other_id, do: {:error, :cannot_friend_self}, else: :ok
  end

  defp validate_no_existing_friendship(user_id, friend_id) do
    case friendship_status(user_id, friend_id) do
      nil ->
        :ok

      "declined" ->
        # Clean up old declined rows before allowing re-send
        from(f in Friendship,
          where:
            (f.user_id == ^user_id and f.friend_id == ^friend_id) or
              (f.user_id == ^friend_id and f.friend_id == ^user_id)
        )
        |> Repo.delete_all()

        :ok

      "pending" ->
        {:error, :already_pending}

      "accepted" ->
        {:error, :already_friends}
    end
  end

  defp broadcast_friend_event(user_id, event) do
    Phoenix.PubSub.broadcast(
      Coinchette.PubSub,
      "user:#{user_id}:friends",
      event
    )
  end
end
