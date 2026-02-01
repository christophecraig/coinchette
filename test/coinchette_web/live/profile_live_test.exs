defmodule CoinchetteWeb.ProfileLiveTest do
  use CoinchetteWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Coinchette.Accounts

  describe "ProfileLive" do
    setup do
      # Create a test user
      {:ok, user} = Accounts.register_user(%{
        email: "test@example.com",
        username: "testplayer",
        password: "password123",
        password_confirmation: "password123"
      })

      # Create some stats for the user
      {:ok, stats} = Accounts.get_or_create_stats(user.id)

      # Simulate some game results
      {:ok, _} = Accounts.record_game_result(user.id, :win, %{
        points_scored: 120,
        points_conceded: 42,
        had_belote_rebelote: true
      })

      {:ok, _} = Accounts.record_game_result(user.id, :loss, %{
        points_scored: 60,
        points_conceded: 102,
        had_belote_rebelote: false
      })

      # Log in the user
      conn = log_in_user(build_conn(), user)

      %{user: user, conn: conn}
    end

    test "displays user profile with statistics", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/profile")

      # Check that the page shows the username
      assert html =~ "Profil de #{user.username}"

      # Check that stats are displayed
      assert html =~ "Parties jouées"
      assert html =~ "Victoires"
      assert html =~ "Défaites"
      assert html =~ "Meilleur score"

      # Check specific stat values
      assert html =~ "2"  # games_played
      assert html =~ "1"  # games_won
      assert html =~ "120"  # best_score
    end

    test "displays win rate", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/profile")

      # Win rate should be 50% (1 win, 1 loss)
      assert html =~ "50.0% de victoires"
    end

    test "displays points statistics", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/profile")

      # Check for points sections
      assert html =~ "Statistiques de points"
      assert html =~ "Points marqués"
      assert html =~ "Points encaissés"
      assert html =~ "Différentiel"
    end

    test "displays achievements section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/profile")

      # Check for achievements
      assert html =~ "Accomplissements"
      assert html =~ "Belote/Rebelote"
      assert html =~ "Ratio victoires"
    end

    test "displays recent games section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/profile")

      # Check for recent games section
      assert html =~ "Historique récent"
    end

    test "shows empty state when no games played", %{conn: conn} do
      # Create a new user with no games
      {:ok, new_user} = Accounts.register_user(%{
        email: "newuser@example.com",
        username: "newuser",
        password: "password123",
        password_confirmation: "password123"
      })

      conn = log_in_user(build_conn(), new_user)
      {:ok, _view, html} = live(conn, ~p"/profile")

      # Should show empty state for games
      assert html =~ "Aucune partie terminée pour le moment"
      assert html =~ "Commencer à jouer"
    end

    test "has a back to lobby link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/profile")

      assert html =~ "Retour au lobby"
    end
  end

  # Helper function to log in a user
  defp log_in_user(conn, user) do
    conn
    |> init_test_session(%{user_id: user.id})
  end
end
