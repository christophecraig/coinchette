defmodule Coinchette.MultiplayerContextTest do
  use Coinchette.DataCase, async: true

  alias Coinchette.{Multiplayer, Accounts}

  describe "create_game/2 with target_score" do
    setup do
      {:ok, user} = Accounts.register_user(%{
        username: "testuser",
        email: "test@example.com",
        password: "password123"
      })

      %{user: user}
    end

    test "creates game with default target_score of 1000", %{user: user} do
      {:ok, game} = Multiplayer.create_game(user.id, variant: "belote")

      assert game.target_score == 1000
      assert game.round_number == 1
      assert game.scores == %{"0" => 0, "1" => 0}
      assert game.status == "waiting"
    end

    test "creates game with custom target_score of 500", %{user: user} do
      {:ok, game} = Multiplayer.create_game(user.id, variant: "belote", target_score: 500)

      assert game.target_score == 500
      assert game.round_number == 1
      assert game.scores == %{"0" => 0, "1" => 0}
    end

    test "initializes cumulative scores to zero", %{user: user} do
      {:ok, game} = Multiplayer.create_game(user.id, variant: "belote")

      assert game.scores["0"] == 0
      assert game.scores["1"] == 0
    end

    test "fails with invalid target_score", %{user: user} do
      {:error, changeset} = Multiplayer.create_game(user.id, variant: "belote", target_score: 999)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).target_score
    end
  end

  describe "update_game_settings/2" do
    setup do
      {:ok, user} = Accounts.register_user(%{
        username: "testuser2",
        email: "test2@example.com",
        password: "password123"
      })

      {:ok, game} = Multiplayer.create_game(user.id, variant: "belote", target_score: 1000)

      %{user: user, game: game}
    end

    test "updates target_score while game is waiting", %{game: game} do
      assert game.status == "waiting"

      {:ok, updated} = Multiplayer.update_game_settings(game.id, %{target_score: 500})

      assert updated.target_score == 500
    end

    test "prevents updating target_score when game is playing", %{game: game} do
      # Change status to playing
      Multiplayer.update_game_status(game.id, "playing")

      {:error, reason} = Multiplayer.update_game_settings(game.id, %{target_score: 500})

      assert reason == :game_already_started
    end

    test "validates target_score when updating", %{game: game} do
      {:error, changeset} = Multiplayer.update_game_settings(game.id, %{target_score: 750})

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).target_score
    end
  end

  describe "update_game_status/3 with round_number and scores" do
    setup do
      {:ok, user} = Accounts.register_user(%{
        username: "testuser3",
        email: "test3@example.com",
        password: "password123"
      })

      {:ok, game} = Multiplayer.create_game(user.id, variant: "belote")

      %{game: game}
    end

    test "updates round_number", %{game: game} do
      {:ok, updated} = Multiplayer.update_game_status(game.id, "playing", %{round_number: 2})

      assert updated.round_number == 2
      assert updated.status == "playing"
    end

    test "updates cumulative scores", %{game: game} do
      new_scores = %{0 => 100, 1 => 62}

      {:ok, updated} = Multiplayer.update_game_status(game.id, "playing", %{scores: new_scores})

      assert updated.scores[0] == 100
      assert updated.scores[1] == 62
    end

    test "updates scores and round_number together", %{game: game} do
      {:ok, updated} = Multiplayer.update_game_status(game.id, "playing", %{
        scores: %{0 => 150, 1 => 80},
        round_number: 3
      })

      assert updated.scores[0] == 150
      assert updated.scores[1] == 80
      assert updated.round_number == 3
    end
  end
end
