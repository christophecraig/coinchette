defmodule Coinchette.Multiplayer.GamePlayer do
  @moduledoc """
  Ecto schema for game players (both human and bot).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_players" do
    field :position, :integer
    field :is_bot, :boolean, default: false
    field :bot_difficulty, :string

    belongs_to :game, Coinchette.Multiplayer.Game
    belongs_to :user, Coinchette.Accounts.User

    timestamps()
  end

  @doc """
  Changeset for creating/updating game players.
  """
  def changeset(game_player, attrs) do
    game_player
    |> cast(attrs, [:game_id, :user_id, :position, :is_bot, :bot_difficulty])
    |> validate_required([:game_id, :position, :is_bot])
    |> validate_number(:position, greater_than_or_equal_to: 0, less_than: 4)
    |> validate_inclusion(:bot_difficulty, ["easy", "medium", "hard"], allow_nil: true)
    |> validate_bot_or_user()
    |> unique_constraint([:game_id, :position])
  end

  defp validate_bot_or_user(changeset) do
    is_bot = get_field(changeset, :is_bot)
    user_id = get_field(changeset, :user_id)

    cond do
      is_bot && user_id != nil ->
        add_error(changeset, :user_id, "cannot be set for bots")

      !is_bot && user_id == nil ->
        add_error(changeset, :user_id, "is required for human players")

      true ->
        changeset
    end
  end
end
