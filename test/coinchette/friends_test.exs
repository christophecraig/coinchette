defmodule Coinchette.FriendsTest do
  use Coinchette.DataCase, async: true

  alias Coinchette.{Friends, Accounts}

  setup do
    {:ok, user1} =
      Accounts.register_user(%{
        username: "alice",
        email: "alice@example.com",
        password: "password123"
      })

    {:ok, user2} =
      Accounts.register_user(%{
        username: "bob",
        email: "bob@example.com",
        password: "password123"
      })

    {:ok, user3} =
      Accounts.register_user(%{
        username: "charlie",
        email: "charlie@example.com",
        password: "password123"
      })

    %{user1: user1, user2: user2, user3: user3}
  end

  describe "send_friend_request/2" do
    test "creates bidirectional pending friendship", %{user1: user1, user2: user2} do
      assert {:ok, _to_user} = Friends.send_friend_request(user1.id, "bob")

      assert Friends.friendship_status(user1.id, user2.id) == "pending"
      assert Friends.friendship_status(user2.id, user1.id) == "pending"
    end

    test "returns error for non-existent user", %{user1: user1} do
      assert {:error, :user_not_found} = Friends.send_friend_request(user1.id, "nobody")
    end

    test "returns error when friending self", %{user1: user1} do
      assert {:error, :cannot_friend_self} = Friends.send_friend_request(user1.id, "alice")
    end

    test "returns error for duplicate request", %{user1: user1} do
      {:ok, _} = Friends.send_friend_request(user1.id, "bob")
      assert {:error, :already_pending} = Friends.send_friend_request(user1.id, "bob")
    end

    test "returns error when already friends", %{user1: user1, user2: user2} do
      {:ok, _} = Friends.send_friend_request(user1.id, "bob")
      {:ok, :ok} = Friends.accept_friend_request(user2.id, user1.id)
      assert {:error, :already_friends} = Friends.send_friend_request(user1.id, "bob")
    end

    test "allows re-sending after decline", %{user1: user1, user2: user2} do
      {:ok, _} = Friends.send_friend_request(user1.id, "bob")
      :ok = Friends.decline_friend_request(user2.id, user1.id)
      assert {:ok, _} = Friends.send_friend_request(user1.id, "bob")
    end
  end

  describe "accept_friend_request/2" do
    test "updates both rows to accepted", %{user1: user1, user2: user2} do
      {:ok, _} = Friends.send_friend_request(user1.id, "bob")
      assert {:ok, :ok} = Friends.accept_friend_request(user2.id, user1.id)

      assert Friends.friendship_status(user1.id, user2.id) == "accepted"
      assert Friends.friendship_status(user2.id, user1.id) == "accepted"
    end

    test "returns error if no pending request", %{user1: user1, user2: user2} do
      assert {:error, :not_found} = Friends.accept_friend_request(user2.id, user1.id)
    end

    test "only the recipient can accept", %{user1: user1, user2: user2} do
      {:ok, _} = Friends.send_friend_request(user1.id, "bob")
      # user1 (sender) cannot accept their own request
      assert {:error, :not_found} = Friends.accept_friend_request(user1.id, user2.id)
    end
  end

  describe "decline_friend_request/2" do
    test "updates both rows to declined", %{user1: user1, user2: user2} do
      {:ok, _} = Friends.send_friend_request(user1.id, "bob")
      assert :ok = Friends.decline_friend_request(user2.id, user1.id)

      assert Friends.friendship_status(user1.id, user2.id) == "declined"
      assert Friends.friendship_status(user2.id, user1.id) == "declined"
    end
  end

  describe "cancel_friend_request/2" do
    test "deletes both rows for outgoing request", %{user1: user1, user2: user2} do
      {:ok, _} = Friends.send_friend_request(user1.id, "bob")
      assert :ok = Friends.cancel_friend_request(user1.id, user2.id)

      assert Friends.friendship_status(user1.id, user2.id) == nil
      assert Friends.friendship_status(user2.id, user1.id) == nil
    end

    test "only the sender can cancel", %{user1: user1, user2: user2} do
      {:ok, _} = Friends.send_friend_request(user1.id, "bob")
      # user2 (recipient) cannot cancel
      assert {:error, :not_found} = Friends.cancel_friend_request(user2.id, user1.id)
    end
  end

  describe "remove_friend/2" do
    test "deletes both rows for accepted friendship", %{user1: user1, user2: user2} do
      {:ok, _} = Friends.send_friend_request(user1.id, "bob")
      {:ok, :ok} = Friends.accept_friend_request(user2.id, user1.id)

      assert :ok = Friends.remove_friend(user1.id, user2.id)
      assert Friends.friendship_status(user1.id, user2.id) == nil
    end
  end

  describe "list_friends/1" do
    test "returns accepted friends", %{user1: user1, user2: user2, user3: user3} do
      {:ok, _} = Friends.send_friend_request(user1.id, "bob")
      {:ok, :ok} = Friends.accept_friend_request(user2.id, user1.id)

      {:ok, _} = Friends.send_friend_request(user1.id, "charlie")
      # charlie not yet accepted

      friends = Friends.list_friends(user1.id)
      assert length(friends) == 1
      assert hd(friends).friend_id == user2.id
      assert hd(friends).username == "bob"

      # Pending request doesn't show
      assert Enum.all?(friends, fn f -> f.friend_id != user3.id end)
    end
  end

  describe "list_pending_requests/1" do
    test "returns received pending requests", %{user1: user1, user2: user2} do
      {:ok, _} = Friends.send_friend_request(user1.id, "bob")

      # bob should see the pending request
      requests = Friends.list_pending_requests(user2.id)
      assert length(requests) == 1
      assert hd(requests).friend_id == user1.id
      assert hd(requests).username == "alice"

      # alice should not see it as a received request
      assert Friends.list_pending_requests(user1.id) == []
    end
  end

  describe "list_sent_requests/1" do
    test "returns sent pending requests", %{user1: user1, user2: user2} do
      {:ok, _} = Friends.send_friend_request(user1.id, "bob")

      # alice should see the sent request
      sent = Friends.list_sent_requests(user1.id)
      assert length(sent) == 1
      assert hd(sent).friend_id == user2.id

      # bob should not see it as a sent request
      assert Friends.list_sent_requests(user2.id) == []
    end
  end

  describe "search_users/3" do
    test "finds users by username", %{user1: user1} do
      results = Friends.search_users(user1.id, "bob")
      assert length(results) == 1
      assert hd(results).username == "bob"
    end

    test "excludes self", %{user1: user1} do
      results = Friends.search_users(user1.id, "alice")
      assert results == []
    end

    test "excludes existing friendships", %{user1: user1} do
      {:ok, _} = Friends.send_friend_request(user1.id, "bob")
      results = Friends.search_users(user1.id, "bob")
      assert results == []
    end

    test "partial match works", %{user1: user1} do
      results = Friends.search_users(user1.id, "cha")
      assert length(results) == 1
      assert hd(results).username == "charlie"
    end
  end
end
