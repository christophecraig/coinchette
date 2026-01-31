defmodule Coinchette.Multiplayer.ChatMessage do
  @moduledoc """
  Ecto schema for chat messages.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_messages" do
    field :message, :string
    field :message_type, :string, default: "user"

    belongs_to :game, Coinchette.Multiplayer.Game
    belongs_to :user, Coinchette.Accounts.User

    timestamps(updated_at: false)
  end

  @doc """
  Changeset for creating chat messages.
  """
  def changeset(chat_message, attrs) do
    chat_message
    |> cast(attrs, [:game_id, :user_id, :message, :message_type])
    |> validate_required([:game_id, :message, :message_type])
    |> validate_inclusion(:message_type, ["user", "system"])
    |> validate_length(:message, min: 1, max: 1000)
  end
end
