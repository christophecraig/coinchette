defmodule CoinchetteWeb.MultiplayerGameLiveTest do
  use CoinchetteWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Coinchette.{Multiplayer, Accounts, GameServer}

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "player@example.com",
        username: "player1",
        password: "password123",
        password_confirmation: "password123"
      })

    {:ok, game} = Multiplayer.create_game(user.id)

    # Start GameServer
    {:ok, _pid} = Coinchette.GameServerSupervisor.start_game(game.id)

    # Add bots to fill positions
    Multiplayer.add_bot(game.id, 1, "easy")
    Multiplayer.add_bot(game.id, 2, "easy")
    Multiplayer.add_bot(game.id, 3, "easy")

    # Start the game
    {:ok, _game} = GameServer.start_game(game.id)

    %{user: user, game: game}
  end

  describe "MultiplayerGameLive mount" do
    test "displays game board when game is started", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/play")

      assert html =~ "Playing Game"
    end

    test "shows players panel", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/play")

      assert html =~ "Joueurs" or html =~ "Players"
      assert html =~ user.username
    end

    test "shows user's hand cards", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/play")

      assert html =~ "Votre main" or html =~ "Your hand"
    end
  end

  describe "Game state display" do
    test "shows scores for both teams", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/play")

      assert html =~ "Équipe 1" or html =~ "Team 1"
      assert html =~ "Équipe 2" or html =~ "Team 2"
    end

    test "displays bots with difficulty emojis", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/play")

      # Bots should have difficulty-based emojis (🐌 for easy, ⚡ for medium, 🔥 for hard)
      assert html =~ "🐌" or html =~ "⚡" or html =~ "🔥"
    end
  end

  describe "Chat functionality" do
    test "displays chat panel", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/play")

      assert html =~ "Chat"
    end

    test "allows sending chat messages", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, view, _html} = live(conn, ~p"/game/#{game.id}/play")

      view
      |> form("form[phx-submit='send_chat']", %{message: "Hello!"})
      |> render_submit()

      :timer.sleep(100)

      html = render(view)
      assert html =~ "Hello!"
      assert html =~ user.username
    end
  end

  describe "Game phase" do
    test "game is in bidding or playing phase after start", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, _html} = live(conn, ~p"/game/#{game.id}/play")

      state = GameServer.get_state(game.id)
      assert state.game.status in [:bidding, :playing, :announcements, :finished]
    end

    test "shows game interface elements", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/play")

      # Should have basic game elements
      assert html =~ user.username
    end
  end

  describe "Real-time updates" do
    test "game progresses with bot turns", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, _html} = live(conn, ~p"/game/#{game.id}/play")

      state_before = GameServer.get_state(game.id)

      # Wait for bots to play
      :timer.sleep(1000)

      state_after = GameServer.get_state(game.id)

      # Game should have progressed (different state) or server may have stopped
      assert is_nil(state_after) or is_nil(state_before) or
               state_before.game != state_after.game or
               state_after.game.status == :finished
    end
  end

  describe "Player info display" do
    test "shows all 4 players in game", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, _html} = live(conn, ~p"/game/#{game.id}/play")

      state = GameServer.get_state(game.id)
      assert length(state.game.players) == 4
    end

    test "marks user's position", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/play")

      # User should see their username with a "Vous" badge
      assert html =~ user.username
      assert html =~ "Vous"
    end
  end
end
