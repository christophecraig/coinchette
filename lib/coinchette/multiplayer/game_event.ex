defmodule Coinchette.Multiplayer.GameEvent do
  @moduledoc """
  Ecto schema for game events (event sourcing).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_events" do
    field :event_type, :string
    field :data, :map
    field :sequence, :integer

    belongs_to :game, Coinchette.Multiplayer.Game
    belongs_to :player, Coinchette.Accounts.User

    timestamps(updated_at: false)
  end

  @doc """
  Changeset for creating game events.
  """
  def changeset(game_event, attrs) do
    game_event
    |> cast(attrs, [:game_id, :event_type, :player_id, :data, :sequence])
    |> validate_required([:game_id, :event_type, :sequence])
    |> validate_inclusion(:event_type, [
      "game_created",
      "player_joined",
      "player_left",
      "game_started",
      "bid_made",
      "card_played",
      "trick_won",
      "round_ended",
      "game_finished"
    ])
  end
end
