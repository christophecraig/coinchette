defmodule Coinchette.GameServerTest do
  use Coinchette.DataCase

  alias Coinchette.{Accounts, Multiplayer, GameServer, GameServerSupervisor}

  setup do
    # Create test users
    {:ok, user1} =
      Accounts.register_user(%{
        email: "player1@example.com",
        username: "player1",
        password: "password123",
        password_confirmation: "password123"
      })

    {:ok, user2} =
      Accounts.register_user(%{
        email: "player2@example.com",
        username: "player2",
        password: "password123",
        password_confirmation: "password123"
      })

    %{user1: user1, user2: user2}
  end

  # Helper to start a game server and allow it to use the test's DB connection
  defp start_game_server(game_id) do
    {:ok, pid} = GameServerSupervisor.start_game(game_id)
    Ecto.Adapters.SQL.Sandbox.allow(Coinchette.Repo, self(), pid)
    {:ok, pid}
  end

  describe "GameServer lifecycle" do
    test "starts and stops successfully", %{user1: user1} do
      {:ok, game} = Multiplayer.create_game(user1.id)

      assert {:ok, pid} = start_game_server(game.id)
      assert Process.alive?(pid)

      assert :ok = GameServerSupervisor.stop_game(game.id)
      refute Process.alive?(pid)
    end

    test "can retrieve game state", %{user1: user1} do
      {:ok, game} = Multiplayer.create_game(user1.id)
      {:ok, _pid} = start_game_server(game.id)

      state = GameServer.get_state(game.id)

      assert state.game_id == game.id
      assert state.game.status == :waiting
      assert state.player_map == %{}
      assert MapSet.size(state.bot_positions) == 0
    end
  end

  describe "player management" do
    test "adds human players", %{user1: user1, user2: user2} do
      {:ok, game} = Multiplayer.create_game(user1.id)
      {:ok, _pid} = start_game_server(game.id)

      assert :ok = GameServer.add_player(game.id, user1.id, 0)
      assert :ok = GameServer.add_player(game.id, user2.id, 2)

      state = GameServer.get_state(game.id)
      assert state.player_map[0] == user1.id
      assert state.player_map[2] == user2.id
      assert MapSet.size(state.bot_positions) == 0
    end

    test "adds bot players", %{user1: user1} do
      {:ok, game} = Multiplayer.create_game(user1.id)
      {:ok, _pid} = start_game_server(game.id)

      assert :ok = GameServer.add_player(game.id, nil, 1, bot: true, difficulty: "easy")
      assert :ok = GameServer.add_player(game.id, nil, 3, bot: true, difficulty: "medium")

      state = GameServer.get_state(game.id)
      assert MapSet.member?(state.bot_positions, 1)
      assert MapSet.member?(state.bot_positions, 3)
    end

    test "removes players", %{user1: user1, user2: user2} do
      {:ok, game} = Multiplayer.create_game(user1.id)
      {:ok, _pid} = start_game_server(game.id)

      :ok = GameServer.add_player(game.id, user1.id, 0)
      :ok = GameServer.add_player(game.id, user2.id, 2)

      assert :ok = GameServer.remove_player(game.id, user1.id)

      state = GameServer.get_state(game.id)
      refute Map.has_key?(state.player_map, 0)
      assert state.player_map[2] == user2.id
    end
  end

  describe "game start" do
    test "starts game with enough players", %{user1: user1, user2: user2} do
      {:ok, game} = Multiplayer.create_game(user1.id)
      {:ok, _pid} = start_game_server(game.id)

      :ok = GameServer.add_player(game.id, user1.id, 0)
      :ok = GameServer.add_player(game.id, user2.id, 2)

      assert {:ok, updated_game} = GameServer.start_game(game.id)
      assert updated_game.status == :bidding
      assert length(updated_game.players) == 4
    end

    test "rejects start with insufficient players", %{user1: user1} do
      {:ok, game} = Multiplayer.create_game(user1.id)
      {:ok, _pid} = start_game_server(game.id)

      :ok = GameServer.add_player(game.id, user1.id, 0)

      assert {:error, :not_enough_players} = GameServer.start_game(game.id)
    end
  end

  describe "PubSub broadcasting" do
    test "broadcasts player joined event", %{user1: user1} do
      {:ok, game} = Multiplayer.create_game(user1.id)
      {:ok, _pid} = start_game_server(game.id)

      # Subscribe to game events
      Phoenix.PubSub.subscribe(Coinchette.PubSub, "game:#{game.id}")

      :ok = GameServer.add_player(game.id, user1.id, 0)

      assert_receive {:player_joined, %{user_id: user_id, position: 0}}, 1000
      assert user_id == user1.id
    end

    test "broadcasts game started event", %{user1: user1, user2: user2} do
      {:ok, game} = Multiplayer.create_game(user1.id)
      {:ok, _pid} = start_game_server(game.id)

      Phoenix.PubSub.subscribe(Coinchette.PubSub, "game:#{game.id}")

      :ok = GameServer.add_player(game.id, user1.id, 0)
      :ok = GameServer.add_player(game.id, user2.id, 2)

      {:ok, _updated_game} = GameServer.start_game(game.id)

      assert_receive {:game_started, _game}, 1000
      assert_receive {:game_updated, game_state}, 1000
      assert game_state.status == :bidding
    end
  end

  describe "persistence" do
    test "persists game state to database", %{user1: user1, user2: user2} do
      {:ok, game} = Multiplayer.create_game(user1.id)
      {:ok, _pid} = start_game_server(game.id)

      :ok = GameServer.add_player(game.id, user1.id, 0)
      :ok = GameServer.add_player(game.id, user2.id, 2)
      {:ok, _updated_game} = GameServer.start_game(game.id)

      # Reload from database
      db_game = Multiplayer.get_game!(game.id)
      assert db_game.status == "playing"
      assert db_game.state != nil
      assert db_game.started_at != nil

      # Verify state can be decoded
      decoded_state = Multiplayer.Game.decode_game_state(db_game.state)
      assert decoded_state.status == :bidding
    end

    test "creates game events", %{user1: user1, user2: user2} do
      {:ok, game} = Multiplayer.create_game(user1.id)
      {:ok, _pid} = start_game_server(game.id)

      :ok = GameServer.add_player(game.id, user1.id, 0)
      :ok = GameServer.add_player(game.id, user2.id, 2)
      {:ok, _updated_game} = GameServer.start_game(game.id)

      events = Multiplayer.list_game_events(game.id)

      # Should have: game_created, 2x player_joined, game_started
      assert length(events) >= 4

      event_types = Enum.map(events, & &1.event_type)
      assert "game_created" in event_types
      assert "player_joined" in event_types
      assert "game_started" in event_types
    end
  end
end
