defmodule Coinchette.Friends.Friendship do
  @moduledoc """
  Schema for friendships between users.

  Uses a bidirectional model: when A sends a request to B, two rows are created
  (A->B and B->A) both with `initiated_by: A`. This simplifies queries.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "friendships" do
    field :status, :string, default: "pending"
    field :initiated_by, :binary_id

    belongs_to :user, Coinchette.Accounts.User
    belongs_to :friend, Coinchette.Accounts.User

    timestamps()
  end

  def changeset(friendship, attrs) do
    friendship
    |> cast(attrs, [:user_id, :friend_id, :status, :initiated_by])
    |> validate_required([:user_id, :friend_id, :status, :initiated_by])
    |> validate_inclusion(:status, ["pending", "accepted", "declined"])
    |> validate_not_self_friend()
    |> unique_constraint([:user_id, :friend_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:friend_id)
  end

  defp validate_not_self_friend(changeset) do
    user_id = get_field(changeset, :user_id)
    friend_id = get_field(changeset, :friend_id)

    if user_id && friend_id && user_id == friend_id do
      add_error(changeset, :friend_id, "cannot be friends with yourself")
    else
      changeset
    end
  end
end
