defmodule CoinchetteWeb.GameHistoryLiveTest do
  use CoinchetteWeb.ConnCase

  import Phoenix.LiveViewTest
  import Ecto.Query

  alias Coinchette.{Multiplayer, Accounts}

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "test@example.com",
        username: "testuser",
        password: "password123",
        password_confirmation: "password123"
      })

    # create_game automatically adds creator as player at position 0
    {:ok, game} = Multiplayer.create_game(user.id)

    # Add bots to other positions
    {:ok, _player2} = Multiplayer.add_bot(game.id, 1, "easy")
    {:ok, _player3} = Multiplayer.add_bot(game.id, 2, "medium")
    {:ok, _player4} = Multiplayer.add_bot(game.id, 3, "hard")

    # Update game to finished status with scores using Repo directly
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    game = Coinchette.Repo.get!(Multiplayer.Game, game.id)
    {:ok, game} = Coinchette.Repo.update(
      Ecto.Changeset.change(game, %{
        status: "finished",
        winner_team: 0,
        scores: %{"0" => 152, "1" => 91},
        started_at: now,
        finished_at: now
      })
    )

    # Add more game events (game_created and player_joined already added by create_game)
    {:ok, _event3} = Multiplayer.add_game_event(game.id, "game_started", %{})
    {:ok, _event4} = Multiplayer.add_game_event(game.id, "game_finished", %{})

    %{user: user, game: game}
  end

  describe "mount" do
    test "redirects if game is not finished", %{user: user} do
      {:ok, user2} =
        Accounts.register_user(%{
          email: "other@example.com",
          username: "otheruser",
          password: "password123",
          password_confirmation: "password123"
        })

      {:ok, unfinished_game} = Multiplayer.create_game(user2.id)
      {:ok, _} = Multiplayer.update_game_status(unfinished_game.id, "playing")

      conn = log_in_user(build_conn(), user)
      result = live(conn, ~p"/game/#{unfinished_game.id}/history")

      # Should redirect with error flash
      assert {:error, {:live_redirect, %{to: "/lobby", flash: flash}}} = result
      assert flash["error"] == "This game is not finished yet"
    end

    test "loads finished game with all data", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, view, _html} = live(conn, ~p"/game/#{game.id}/history")

      assert has_element?(view, "h1", "Historique de partie")
    end

    test "displays game summary information", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/history")

      assert html =~ "Résumé"
      assert html =~ "Vainqueur"
      assert html =~ "Équipe 1"
      assert html =~ "Score final"
      assert html =~ "152"
      assert html =~ "91"
    end

    test "shows player information organized by teams", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/history")

      assert html =~ "Joueurs"
      assert html =~ user.username
      assert html =~ "Bot (easy)"
      assert html =~ "Bot (medium)"
      assert html =~ "Bot (hard)"
    end

    test "highlights winning team", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/history")

      # Winner team should have special styling
      assert html =~ "badge-success"
      assert html =~ "Vainqueur"
    end

    test "displays event timeline", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/history")

      assert html =~ "Chronologie des événements"
      assert html =~ "Partie créée"
      assert html =~ "a rejoint la partie"
      assert html =~ "La partie a commencé"
      assert html =~ "Partie terminée"
    end

    test "identifies current user in player list", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/history")

      assert html =~ "Vous"
    end

    test "displays game duration", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/history")

      assert html =~ "Durée"
    end

    test "shows back to profile link", %{user: user, game: game} do
      conn = log_in_user(build_conn(), user)
      {:ok, view, _html} = live(conn, ~p"/game/#{game.id}/history")

      assert has_element?(view, "a[href='/profile']", "Retour au profil")
    end
  end

  describe "game details panel" do
    test "displays trump suit when present in game state", %{user: user, game: game} do
      # Create a simple game state struct for encoding
      game_struct = %Coinchette.Games.Game{
        trump_suit: :hearts,
        status: :finished
      }

      encoded_state = Coinchette.Multiplayer.Game.encode_game_state(game_struct)

      # Update game with encoded state using Repo
      game = Coinchette.Repo.get!(Multiplayer.Game, game.id)
      {:ok, _game} = Coinchette.Repo.update(
        Ecto.Changeset.change(game, %{state: encoded_state})
      )

      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/history")

      assert html =~ "Atout"
      assert html =~ "♥"
      assert html =~ "Cœur"
    end

    test "displays tricks won breakdown", %{user: user, game: game} do
      # Create game struct with tricks
      alias Coinchette.Games.{Card, Trick}

      trick1 = %Trick{
        cards: [
          {%Card{rank: :ace, suit: :hearts}, 0},
          {%Card{rank: :king, suit: :hearts}, 1},
          {%Card{rank: :queen, suit: :hearts}, 2},
          {%Card{rank: :jack, suit: :hearts}, 3}
        ]
      }

      trick2 = %Trick{
        cards: [
          {%Card{rank: :ace, suit: :spades}, 1},
          {%Card{rank: :king, suit: :spades}, 2},
          {%Card{rank: :queen, suit: :spades}, 3},
          {%Card{rank: :jack, suit: :spades}, 0}
        ]
      }

      game_struct = %Coinchette.Games.Game{
        trump_suit: :spades,
        tricks_won: [{0, trick1}, {1, trick2}],
        status: :finished
      }

      encoded_state = Coinchette.Multiplayer.Game.encode_game_state(game_struct)

      game = Coinchette.Repo.get!(Multiplayer.Game, game.id)
      {:ok, _game} = Coinchette.Repo.update(
        Ecto.Changeset.change(game, %{state: encoded_state})
      )

      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/history")

      assert html =~ "Plis remportés"
      assert html =~ "Équipe 1:"
      assert html =~ "Équipe 2:"
      assert html =~ "Historique des plis"
    end

    test "displays Belote/Rebelote when present", %{user: user, game: game} do
      game_struct = %Coinchette.Games.Game{
        trump_suit: :hearts,
        belote_rebelote: {0, [:belote, :rebelote]},
        status: :finished
      }

      encoded_state = Coinchette.Multiplayer.Game.encode_game_state(game_struct)

      game = Coinchette.Repo.get!(Multiplayer.Game, game.id)
      {:ok, _game} = Coinchette.Repo.update(
        Ecto.Changeset.change(game, %{state: encoded_state})
      )

      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/history")

      assert html =~ "Belote/Rebelote"
      assert html =~ "👑"
      assert html =~ "+20 points"
    end
  end

  describe "helper functions" do
    test "calculates game duration correctly", %{user: user} do
      started_at = ~N[2026-01-01 10:00:00]
      finished_at = ~N[2026-01-01 10:15:30]

      {:ok, game} = Multiplayer.create_game(user.id)

      # Update using Repo directly
      game = Coinchette.Repo.get!(Multiplayer.Game, game.id)
      {:ok, game} = Coinchette.Repo.update(
        Ecto.Changeset.change(game, %{
          status: "finished",
          started_at: started_at,
          finished_at: finished_at,
          winner_team: 0,
          scores: %{"0" => 100, "1" => 50}
        })
      )

      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/history")

      assert html =~ "15m 30s"
    end

    test "displays N/A when no events recorded", %{user: user} do
      {:ok, game} = Multiplayer.create_game(user.id)

      # Update using Repo directly
      game = Coinchette.Repo.get!(Multiplayer.Game, game.id)
      {:ok, game} = Coinchette.Repo.update(
        Ecto.Changeset.change(game, %{
          status: "finished",
          winner_team: 0,
          scores: %{"0" => 100, "1" => 50}
        })
      )

      # Delete all events
      game_id = game.id
      Coinchette.Repo.delete_all(
        from e in Coinchette.Multiplayer.GameEvent, where: e.game_id == ^game_id
      )

      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/game/#{game.id}/history")

      assert html =~ "Aucun événement enregistré"
    end
  end

  # Helper function to log in a user
  defp log_in_user(conn, user) do
    conn
    |> init_test_session(%{user_id: user.id})
  end
end
