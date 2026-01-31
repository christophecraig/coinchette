defmodule Coinchette.MultiplayerTest do
  use Coinchette.DataCase

  alias Coinchette.{Accounts, Multiplayer}
  alias Coinchette.Multiplayer.{Game, GamePlayer}

  describe "games" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{
          email: "test@example.com",
          username: "testuser",
          password: "password123",
          password_confirmation: "password123"
        })

      %{user: user}
    end

    test "create_game/2 creates a game with valid data", %{user: user} do
      assert {:ok, %Game{} = game} = Multiplayer.create_game(user.id)
      assert game.variant == "belote"
      assert game.mode == "multi"
      assert game.status == "waiting"
      assert game.creator_id == user.id
      assert game.is_private == true
      assert game.max_players == 4
      assert String.length(game.room_code) == 6
    end

    test "create_game/2 with custom variant", %{user: user} do
      assert {:ok, %Game{} = game} = Multiplayer.create_game(user.id, variant: "coinche")
      assert game.variant == "coinche"
    end

    test "create_game/2 generates unique room codes", %{user: user} do
      {:ok, game1} = Multiplayer.create_game(user.id)
      {:ok, game2} = Multiplayer.create_game(user.id)
      assert game1.room_code != game2.room_code
    end

    test "get_game!/1 returns game with preloaded associations", %{user: user} do
      {:ok, created_game} = Multiplayer.create_game(user.id)
      game = Multiplayer.get_game!(created_game.id)
      assert game.id == created_game.id
      assert game.creator.id == user.id
    end

    test "get_game_by_room_code/1 returns game", %{user: user} do
      {:ok, created_game} = Multiplayer.create_game(user.id)
      game = Multiplayer.get_game_by_room_code(created_game.room_code)
      assert game.id == created_game.id
    end

    test "get_game_by_room_code/1 returns nil for invalid code" do
      assert Multiplayer.get_game_by_room_code("INVALID") == nil
    end

    test "list_user_games/2 lists games for creator", %{user: user} do
      {:ok, game1} = Multiplayer.create_game(user.id)
      {:ok, game2} = Multiplayer.create_game(user.id)

      games = Multiplayer.list_user_games(user.id)
      assert length(games) == 2
      assert Enum.any?(games, &(&1.id == game1.id))
      assert Enum.any?(games, &(&1.id == game2.id))
    end

    test "list_user_games/2 with status filter", %{user: user} do
      {:ok, _game1} = Multiplayer.create_game(user.id)
      {:ok, game2} = Multiplayer.create_game(user.id)
      Multiplayer.update_game_status(game2.id, "finished")

      waiting_games = Multiplayer.list_user_games(user.id, status: "waiting")
      finished_games = Multiplayer.list_user_games(user.id, status: "finished")

      assert length(waiting_games) == 1
      assert length(finished_games) == 1
    end
  end

  describe "game players" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{
          email: "player@example.com",
          username: "player",
          password: "password123",
          password_confirmation: "password123"
        })

      {:ok, game} = Multiplayer.create_game(user.id)

      %{user: user, game: game}
    end

    test "add_player/3 adds a human player", %{user: user, game: game} do
      assert {:ok, %GamePlayer{} = player} = Multiplayer.add_player(game.id, user.id, 0)
      assert player.user_id == user.id
      assert player.position == 0
      assert player.is_bot == false
    end

    test "add_player/3 prevents duplicate positions", %{user: user, game: game} do
      {:ok, _player} = Multiplayer.add_player(game.id, user.id, 0)

      {:ok, user2} =
        Accounts.register_user(%{
          email: "player2@example.com",
          username: "player2",
          password: "password123",
          password_confirmation: "password123"
        })

      assert {:error, changeset} = Multiplayer.add_player(game.id, user2.id, 0)
      # The constraint is on [:game_id, :position] but Ecto reports it as :game_id
      assert %{game_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "add_bot/3 adds a bot player", %{game: game} do
      assert {:ok, %GamePlayer{} = bot} = Multiplayer.add_bot(game.id, 1, "easy")
      assert bot.position == 1
      assert bot.is_bot == true
      assert bot.bot_difficulty == "easy"
      assert bot.user_id == nil
    end

    test "remove_player/2 removes a player", %{user: user, game: game} do
      {:ok, _player} = Multiplayer.add_player(game.id, user.id, 0)
      assert {:ok, 1} = Multiplayer.remove_player(game.id, user.id)

      players = Multiplayer.list_game_players(game.id)
      assert length(players) == 0
    end

    test "list_game_players/1 returns players in position order", %{user: user, game: game} do
      {:ok, _player} = Multiplayer.add_player(game.id, user.id, 2)
      {:ok, _bot1} = Multiplayer.add_bot(game.id, 0, "easy")
      {:ok, _bot2} = Multiplayer.add_bot(game.id, 3, "medium")

      players = Multiplayer.list_game_players(game.id)
      assert length(players) == 3
      assert Enum.map(players, & &1.position) == [0, 2, 3]
    end
  end

  describe "game events" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{
          email: "event@example.com",
          username: "eventuser",
          password: "password123",
          password_confirmation: "password123"
        })

      {:ok, game} = Multiplayer.create_game(user.id)

      %{user: user, game: game}
    end

    test "add_game_event/3 creates an event", %{game: game, user: user} do
      assert {:ok, event} =
               Multiplayer.add_game_event(game.id, "card_played", %{
                 user_id: user.id,
                 card: "AS"
               })

      assert event.event_type == "card_played"
      # JSONB stores with string keys
      assert event.data[:card] == "AS" or event.data["card"] == "AS"
    end

    test "add_game_event/3 maintains sequence order", %{game: game} do
      {:ok, event1} = Multiplayer.add_game_event(game.id, "game_started", %{})
      {:ok, event2} = Multiplayer.add_game_event(game.id, "bid_made", %{})
      {:ok, event3} = Multiplayer.add_game_event(game.id, "card_played", %{})

      assert event1.sequence < event2.sequence
      assert event2.sequence < event3.sequence
    end

    test "list_game_events/1 returns events in order", %{game: game} do
      Multiplayer.add_game_event(game.id, "game_started", %{})
      Multiplayer.add_game_event(game.id, "bid_made", %{})
      Multiplayer.add_game_event(game.id, "card_played", %{})

      events = Multiplayer.list_game_events(game.id)
      # +3 for the events we added, +1 for game_created from create_game
      assert length(events) == 4

      sequences = Enum.map(events, & &1.sequence)
      assert sequences == Enum.sort(sequences)
    end
  end

  describe "chat messages" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{
          email: "chat@example.com",
          username: "chatuser",
          password: "password123",
          password_confirmation: "password123"
        })

      {:ok, game} = Multiplayer.create_game(user.id)

      %{user: user, game: game}
    end

    test "send_chat_message/4 creates a message", %{game: game, user: user} do
      assert {:ok, message} = Multiplayer.send_chat_message(game.id, user.id, "Hello!")
      assert message.message == "Hello!"
      assert message.user_id == user.id
      assert message.message_type == "user"
    end

    test "send_chat_message/4 with system message", %{game: game} do
      assert {:ok, message} = Multiplayer.send_chat_message(game.id, nil, "Game started", "system")
      assert message.message_type == "system"
      assert message.user_id == nil
    end

    test "list_chat_messages/2 returns messages in chronological order", %{game: game, user: user} do
      Multiplayer.send_chat_message(game.id, user.id, "First")
      Multiplayer.send_chat_message(game.id, user.id, "Second")
      Multiplayer.send_chat_message(game.id, user.id, "Third")

      messages = Multiplayer.list_chat_messages(game.id)
      assert length(messages) == 3
      assert Enum.map(messages, & &1.message) == ["First", "Second", "Third"]
    end

    test "list_chat_messages/2 respects limit", %{game: game, user: user} do
      for i <- 1..10 do
        Multiplayer.send_chat_message(game.id, user.id, "Message #{i}")
      end

      messages = Multiplayer.list_chat_messages(game.id, limit: 5)
      assert length(messages) == 5
    end
  end

  describe "room code generation" do
    test "generate_room_code/0 generates 6-character code" do
      code = Multiplayer.generate_room_code()
      assert String.length(code) == 6
      assert code =~ ~r/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/
    end

    test "generate_room_code/0 does not include confusing characters" do
      # Generate many codes to check
      codes = for _ <- 1..100, do: Multiplayer.generate_room_code()

      Enum.each(codes, fn code ->
        refute String.contains?(code, ["O", "0", "I", "1"])
      end)
    end
  end
end
