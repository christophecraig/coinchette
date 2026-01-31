defmodule Coinchette.Multiplayer.Game do
  @moduledoc """
  Ecto schema for multiplayer games.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "games" do
    field :variant, :string
    field :mode, :string
    field :status, :string
    field :state, :binary  # Binary serialized Game struct
    field :winner_team, :integer
    field :scores, :map
    field :started_at, :naive_datetime
    field :finished_at, :naive_datetime

    # Multiplayer fields
    field :room_code, :string
    field :is_private, :boolean, default: true
    field :max_players, :integer, default: 4
    field :version, :integer, default: 0

    belongs_to :creator, Coinchette.Accounts.User
    belongs_to :current_turn_player, Coinchette.Accounts.User

    has_many :game_players, Coinchette.Multiplayer.GamePlayer
    has_many :game_events, Coinchette.Multiplayer.GameEvent
    has_many :chat_messages, Coinchette.Multiplayer.ChatMessage

    timestamps()
  end

  @doc """
  Changeset for creating a new game.
  """
  def creation_changeset(game, attrs) do
    game
    |> cast(attrs, [:variant, :mode, :status, :room_code, :creator_id, :is_private, :max_players])
    |> validate_required([:variant, :mode, :status, :room_code, :creator_id])
    |> validate_inclusion(:variant, ["belote", "coinche"])
    |> validate_inclusion(:mode, ["solo", "multi"])
    |> validate_inclusion(:status, ["waiting", "playing", "finished"])
    |> validate_number(:max_players, greater_than: 1, less_than_or_equal_to: 4)
    |> unique_constraint(:room_code)
  end

  @doc """
  Changeset for updating game state.
  """
  def state_changeset(game, attrs) do
    changeset =
      game
      |> cast(attrs, [:state, :status, :current_turn_player_id, :winner_team, :scores, :started_at, :finished_at])

    # Only apply optimistic locking if version is being updated
    if Map.has_key?(attrs, :version) do
      optimistic_lock(changeset, :version)
    else
      changeset
    end
  end

  @doc """
  Encodes a Game struct to binary format for storage.
  """
  def encode_game_state(%Coinchette.Games.Game{} = game) do
    :erlang.term_to_binary(game)
  end

  @doc """
  Decodes a binary game state back to a Game struct.
  """
  def decode_game_state(nil), do: nil
  def decode_game_state(binary) when is_binary(binary) do
    :erlang.binary_to_term(binary)
  end
end
