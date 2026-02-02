defmodule CoinchetteWeb.LobbyLiveTest do
  use CoinchetteWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Coinchette.{Multiplayer, Accounts}

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "test@example.com",
        username: "testplayer",
        password: "password123",
        password_confirmation: "password123"
      })

    conn = log_in_user(build_conn(), user)

    %{conn: conn, user: user}
  end

  describe "LobbyLive mount" do
    test "displays the lobby page when logged in", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/lobby")

      assert html =~ "Game Lobby"
      assert html =~ "Create New Game"
    end

    test "redirects to login when not authenticated" do
      conn = build_conn()
      {:error, {:redirect, %{to: to}}} = live(conn, ~p"/login")

      assert to =~ "/login"
    end
  end

  describe "Create game" do
    test "creates a new game and redirects to game lobby", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      # Click create game button using data-testid
      view
      |> element("button[data-testid='create-game-button']")
      |> render_click()

      # Should redirect to game lobby (flash redirect)
      assert_redirected(view, ~r"/game/.+/lobby")
    end

    test "creates game with belote variant by default", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      view
      |> element("button[data-testid='create-game-button']")
      |> render_click()

      # Check that game was created
      games = Multiplayer.list_user_games(user.id)
      assert length(games) >= 1
      game = hd(games)
      assert game.variant == "belote"
      assert game.status == "waiting"
      assert game.creator_id == user.id
    end
  end

  describe "Join game" do
    test "joins a game by room code", %{conn: conn} do
      # Create another user and their game
      {:ok, other_user} =
        Accounts.register_user(%{
          email: "other@example.com",
          username: "otherplayer",
          password: "password123",
          password_confirmation: "password123"
        })

      {:ok, game} = Multiplayer.create_game(other_user.id)

      {:ok, view, _html} = live(conn, ~p"/lobby")

      # Submit join form
      view
      |> form("form[phx-submit='join_game']", %{room_code: game.room_code})
      |> render_submit()

      # Should redirect to game lobby
      assert_redirected(view, ~r"/game/.+/lobby")
    end

    test "shows error for invalid room code", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      view
      |> form("form[phx-submit='join_game']", %{room_code: "INVALID"})
      |> render_submit()

      assert render(view) =~ "not found" or render(view) =~ "Game not found"
    end
  end

  describe "Active games list" do
    test "displays user's active games", %{conn: conn, user: user} do
      # Create some games
      {:ok, game1} = Multiplayer.create_game(user.id)
      {:ok, _game2} = Multiplayer.create_game(user.id)

      {:ok, _view, html} = live(conn, ~p"/lobby")

      assert html =~ game1.room_code
      assert html =~ "waiting" or html =~ "playing"
    end

    test "shows empty state when no games", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/lobby")

      assert html =~ "No active games" or html =~ "Aucune partie"
    end

    test "allows clicking on game to navigate", %{conn: conn, user: user} do
      {:ok, game} = Multiplayer.create_game(user.id)

      {:ok, view, _html} = live(conn, ~p"/lobby")

      # Click on game card
      view
      |> element("[data-testid='game-card-#{game.id}']")
      |> render_click()

      assert_redirected(view, "/game/#{game.id}/lobby")
    end
  end

  describe "Profile navigation" do
    test "has link to profile page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      assert has_element?(view, "a[href='/profile']") or
               has_element?(view, "a[navigate='/profile']")
    end
  end
end
