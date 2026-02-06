defmodule CoinchetteWeb.GameLobbyLiveTest do
  use CoinchetteWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Coinchette.{Multiplayer, Accounts}

  setup do
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

    {:ok, game} = Multiplayer.create_game(user1.id)

    # Start GameServer for the game
    {:ok, _pid} = Coinchette.GameServerSupervisor.start_game(game.id)

    %{user1: user1, user2: user2, game: game}
  end

  describe "GameLobbyLive mount as creator" do
    test "displays game lobby with room code", %{user1: user1, game: game} do
      conn = log_in_user(build_conn(), user1)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/lobby")

      assert html =~ "Game Lobby"
      assert html =~ game.room_code
      assert html =~ "Room Code"
    end

    test "shows start game button for creator", %{user1: user1, game: game} do
      conn = log_in_user(build_conn(), user1)
      {:ok, view, _html} = live(conn, ~p"/game/#{game.id}/lobby")

      assert has_element?(view, "button[data-testid='start-game-button']")
    end

    test "shows delete game button for creator in waiting status", %{user1: user1, game: game} do
      conn = log_in_user(build_conn(), user1)
      {:ok, view, _html} = live(conn, ~p"/game/#{game.id}/lobby")

      assert has_element?(view, "button[phx-click='delete_game']")
    end

    test "shows player at position 0", %{user1: user1, game: game} do
      conn = log_in_user(build_conn(), user1)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/lobby")

      assert html =~ user1.username
    end
  end

  describe "GameLobbyLive mount as non-player" do
    test "shows join button for non-players", %{user2: user2, game: game} do
      conn = log_in_user(build_conn(), user2)
      {:ok, view, _html} = live(conn, ~p"/game/#{game.id}/lobby")

      assert has_element?(view, "button[phx-click='join_game']")
    end
  end

  describe "Join game" do
    test "allows non-player to join", %{user2: user2, game: game} do
      conn = log_in_user(build_conn(), user2)
      {:ok, view, _html} = live(conn, ~p"/game/#{game.id}/lobby")

      view
      |> element("button[phx-click='join_game']")
      |> render_click()

      html = render(view)
      assert html =~ user2.username
    end
  end

  describe "Leave game" do
    test "allows player to leave and redirects to lobby", %{user1: user1, game: game} do
      conn = log_in_user(build_conn(), user1)
      {:ok, view, _html} = live(conn, ~p"/game/#{game.id}/lobby")

      view
      |> element("button[phx-click='leave_game']")
      |> render_click()

      {path, _flash} = assert_redirect(view)
      assert path =~ "/lobby"
    end
  end

  describe "Start game" do
    test "creator can start game and gets redirected", %{user1: user1, game: game} do
      conn = log_in_user(build_conn(), user1)
      {:ok, view, _html} = live(conn, ~p"/game/#{game.id}/lobby")

      view
      |> element("button[data-testid='start-game-button']")
      |> render_click()

      {path, _flash} = assert_redirect(view)
      assert path =~ "/play"
    end

    test "auto-fills empty positions with bots", %{user1: user1, game: game} do
      conn = log_in_user(build_conn(), user1)
      {:ok, view, _html} = live(conn, ~p"/game/#{game.id}/lobby")

      view
      |> element("button[data-testid='start-game-button']")
      |> render_click()

      # Check that bots were added
      players = Multiplayer.list_game_players(game.id)
      assert length(players) == 4
      bot_count = Enum.count(players, & &1.is_bot)
      assert bot_count == 3
    end
  end

  describe "Delete game" do
    test "creator can delete waiting game", %{user1: user1, game: game} do
      conn = log_in_user(build_conn(), user1)
      {:ok, view, _html} = live(conn, ~p"/game/#{game.id}/lobby")

      view
      |> element("button[phx-click='delete_game']")
      |> render_click()

      {path, _flash} = assert_redirect(view)
      assert path =~ "/lobby"

      # Verify game was deleted
      assert Multiplayer.get_game_by_room_code(game.room_code) == nil
    end

    test "non-creator cannot see delete button", %{user2: user2, game: game} do
      Multiplayer.add_player(game.id, user2.id, 1)

      conn = log_in_user(build_conn(), user2)
      {:ok, view, _html} = live(conn, ~p"/game/#{game.id}/lobby")

      refute has_element?(view, "button[phx-click='delete_game']")
    end
  end

  describe "Players display" do
    test "shows all 4 player slots", %{user1: user1, game: game} do
      conn = log_in_user(build_conn(), user1)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/lobby")

      # Should show team composition (French UI)
      assert html =~ "Composition des équipes" or html =~ "Players"
      assert html =~ "/4"
    end

    test "shows bot emoji for bot players", %{user1: user1, game: game} do
      Multiplayer.add_bot(game.id, 1, "easy")

      conn = log_in_user(build_conn(), user1)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/lobby")

      assert html =~ "🤖"
    end
  end

  describe "Room code display" do
    test "displays room code", %{user1: user1, game: game} do
      conn = log_in_user(build_conn(), user1)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/lobby")

      assert html =~ game.room_code
      assert html =~ "Room Code"
    end

    test "has copy button for room code", %{user1: user1, game: game} do
      conn = log_in_user(build_conn(), user1)
      {:ok, view, _html} = live(conn, ~p"/game/#{game.id}/lobby")

      assert has_element?(view, "button[title='Copy room code']")
    end
  end
end
