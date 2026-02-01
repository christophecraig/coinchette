defmodule CoinchetteWeb.PresenceTest do
  use CoinchetteWeb.ConnCase

  alias CoinchetteWeb.Presence

  describe "Presence tracking" do
    test "tracks users in a game" do
      topic = "game:test-123"
      user_id = "user-1"

      # Track a user
      {:ok, _} = Presence.track(self(), topic, user_id, %{
        username: "testuser",
        joined_at: System.system_time(:second)
      })

      # Wait a bit for presence to propagate
      Process.sleep(50)

      # List present users
      presences = Presence.list(topic)

      assert Map.has_key?(presences, user_id)
      assert presences[user_id].metas |> hd() |> Map.get(:username) == "testuser"
    end

    test "removes users when process terminates" do
      topic = "game:test-456"
      user_id = "user-2"

      # Spawn a process to track presence
      pid = spawn(fn ->
        {:ok, _} = Presence.track(self(), topic, user_id, %{
          username: "testuser2",
          joined_at: System.system_time(:second)
        })

        receive do
          :stop -> :ok
        end
      end)

      # Wait for presence to propagate
      Process.sleep(50)

      # Verify user is present
      presences = Presence.list(topic)
      assert Map.has_key?(presences, user_id)

      # Kill the process
      Process.exit(pid, :kill)

      # Wait for presence to update
      Process.sleep(100)

      # Verify user is no longer present
      presences = Presence.list(topic)
      refute Map.has_key?(presences, user_id)
    end

    test "tracks multiple users in the same game" do
      topic = "game:test-789"

      # Track multiple users
      {:ok, _} = Presence.track(self(), topic, "user-1", %{username: "player1"})
      {:ok, _} = Presence.track(self(), topic, "user-2", %{username: "player2"})
      {:ok, _} = Presence.track(self(), topic, "user-3", %{username: "player3"})

      Process.sleep(50)

      # List all present users
      presences = Presence.list(topic)

      assert map_size(presences) == 3
      assert Map.has_key?(presences, "user-1")
      assert Map.has_key?(presences, "user-2")
      assert Map.has_key?(presences, "user-3")
    end
  end
end
