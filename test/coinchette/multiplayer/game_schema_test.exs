defmodule Coinchette.Multiplayer.GameSchemaTest do
  use Coinchette.DataCase, async: true

  alias Coinchette.Multiplayer.Game

  describe "creation_changeset/2" do
    test "accepts valid target_score of 500" do
      attrs = %{
        variant: "belote",
        mode: "multi",
        status: "waiting",
        room_code: "ABC123",
        creator_id: Ecto.UUID.generate(),
        target_score: 500
      }

      changeset = Game.creation_changeset(%Game{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :target_score) == 500
    end

    test "accepts valid target_score of 1000" do
      attrs = %{
        variant: "belote",
        mode: "multi",
        status: "waiting",
        room_code: "ABC123",
        creator_id: Ecto.UUID.generate(),
        target_score: 1000
      }

      changeset = Game.creation_changeset(%Game{}, attrs)

      assert changeset.valid?
      # When value equals default, it won't be in changes, check applied value
      game = apply_changes(changeset)
      assert game.target_score == 1000
    end

    test "rejects target_score of 750" do
      attrs = %{
        variant: "belote",
        mode: "multi",
        status: "waiting",
        room_code: "ABC123",
        creator_id: Ecto.UUID.generate(),
        target_score: 750
      }

      changeset = Game.creation_changeset(%Game{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).target_score
    end

    test "rejects target_score of 0" do
      attrs = %{
        variant: "belote",
        mode: "multi",
        status: "waiting",
        room_code: "ABC123",
        creator_id: Ecto.UUID.generate(),
        target_score: 0
      }

      changeset = Game.creation_changeset(%Game{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).target_score
    end

    test "uses default target_score of 1000 if not provided" do
      attrs = %{
        variant: "belote",
        mode: "multi",
        status: "waiting",
        room_code: "ABC123",
        creator_id: Ecto.UUID.generate()
      }

      changeset = Game.creation_changeset(%Game{}, attrs)

      assert changeset.valid?

      # Default value is set at schema level
      game = %Game{} |> Game.creation_changeset(attrs) |> apply_changes()
      assert game.target_score == 1000
    end

    test "defaults round_number to 1" do
      game = %Game{}
      assert game.round_number == 1
    end
  end

  describe "state_changeset/2" do
    test "allows updating round_number" do
      game = %Game{round_number: 1}

      changeset = Game.state_changeset(game, %{round_number: 2})

      assert changeset.valid?
      assert get_change(changeset, :round_number) == 2
    end

    test "allows updating scores map" do
      game = %Game{scores: %{"0" => 0, "1" => 0}}

      new_scores = %{"0" => 100, "1" => 62}
      changeset = Game.state_changeset(game, %{scores: new_scores})

      assert changeset.valid?
      assert get_change(changeset, :scores) == new_scores
    end
  end

  describe "game struct defaults" do
    test "new game has correct default values" do
      game = %Game{}

      assert game.target_score == 1000
      assert game.round_number == 1
      assert game.status == nil  # Not set until creation_changeset
    end
  end
end
