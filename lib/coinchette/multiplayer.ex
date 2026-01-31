defmodule Coinchette.Multiplayer do
  @moduledoc """
  The Multiplayer context handles game management, players, events, and chat.
  """

  import Ecto.Query, warn: false
  alias Coinchette.Repo
  alias Coinchette.Multiplayer.{Game, GamePlayer, GameEvent, ChatMessage}

  ## Games

  @doc """
  Creates a new multiplayer game.

  ## Examples

      iex> create_game(user_id, variant: "belote")
      {:ok, %Game{}}

  """
  def create_game(creator_id, opts \\ []) do
    variant = Keyword.get(opts, :variant, "belote")
    is_private = Keyword.get(opts, :is_private, true)

    attrs = %{
      variant: variant,
      mode: "multi",
      status: "waiting",
      room_code: generate_room_code(),
      creator_id: creator_id,
      is_private: is_private,
      max_players: 4
    }

    %Game{}
    |> Game.creation_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, game} = result ->
        # Create initial event
        add_game_event(game.id, "game_created", %{creator_id: creator_id, variant: variant})
        result

      error ->
        error
    end
  end

  @doc """
  Gets a single game by ID with preloaded associations.
  """
  def get_game!(id) do
    Game
    |> preload([:creator, :game_players, :current_turn_player])
    |> Repo.get!(id)
  end

  @doc """
  Gets a game by room code.
  """
  def get_game_by_room_code(room_code) when is_binary(room_code) do
    Game
    |> where([g], g.room_code == ^room_code)
    |> preload([:creator, :game_players, :current_turn_player])
    |> Repo.one()
  end

  @doc """
  Lists all games for a user (as player or creator).
  """
  def list_user_games(user_id, opts \\ []) do
    status = Keyword.get(opts, :status)

    query =
      from g in Game,
        left_join: gp in GamePlayer,
        on: gp.game_id == g.id,
        where: g.creator_id == ^user_id or gp.user_id == ^user_id,
        order_by: [desc: g.updated_at],
        preload: [:creator, :game_players]

    query =
      if status do
        where(query, [g], g.status == ^status)
      else
        query
      end

    query
    |> distinct([g], g.id)
    |> Repo.all()
  end

  @doc """
  Updates the game state (for GenServer persistence).
  """
  def update_game_state(game_id, %Coinchette.Games.Game{} = game_struct) do
    game = Repo.get!(Game, game_id)

    attrs = %{
      state: Game.encode_game_state(game_struct),
      status: determine_status(game_struct),
      version: game.version + 1
    }

    game
    |> Game.state_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates game status and metadata.
  """
  def update_game_status(game_id, status, metadata \\ %{}) do
    # Reload to get latest version
    game = Repo.get!(Game, game_id)

    attrs =
      %{status: status}
      |> Map.merge(metadata)

    game
    |> Game.state_changeset(attrs)
    |> Repo.update()
  end

  defp determine_status(%Coinchette.Games.Game{} = game) do
    cond do
      game.status == :finished -> "finished"
      game.status == :playing -> "playing"
      true -> "waiting"
    end
  end

  ## Game Players

  @doc """
  Adds a player to a game.
  """
  def add_player(game_id, user_id, position) do
    %GamePlayer{}
    |> GamePlayer.changeset(%{
      game_id: game_id,
      user_id: user_id,
      position: position,
      is_bot: false
    })
    |> Repo.insert()
    |> case do
      {:ok, _player} = result ->
        add_game_event(game_id, "player_joined", %{user_id: user_id, position: position})
        result

      error ->
        error
    end
  end

  @doc """
  Adds a bot to a game.
  """
  def add_bot(game_id, position, difficulty) when difficulty in ["easy", "medium", "hard"] do
    %GamePlayer{}
    |> GamePlayer.changeset(%{
      game_id: game_id,
      position: position,
      is_bot: true,
      bot_difficulty: difficulty
    })
    |> Repo.insert()
  end

  @doc """
  Removes a player from a game.
  """
  def remove_player(game_id, user_id) do
    query =
      from gp in GamePlayer,
        where: gp.game_id == ^game_id and gp.user_id == ^user_id

    case Repo.delete_all(query) do
      {count, _} when count > 0 ->
        add_game_event(game_id, "player_left", %{user_id: user_id})
        {:ok, count}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Lists all players for a game.
  """
  def list_game_players(game_id) do
    GamePlayer
    |> where([gp], gp.game_id == ^game_id)
    |> order_by([gp], gp.position)
    |> preload(:user)
    |> Repo.all()
  end

  ## Game Events

  @doc """
  Adds an event to a game's event log.
  """
  def add_game_event(game_id, event_type, data \\ %{}) do
    # Get the next sequence number
    sequence =
      GameEvent
      |> where([ge], ge.game_id == ^game_id)
      |> select([ge], max(ge.sequence))
      |> Repo.one()
      |> case do
        nil -> 0
        max_seq -> max_seq + 1
      end

    %GameEvent{}
    |> GameEvent.changeset(%{
      game_id: game_id,
      event_type: event_type,
      player_id: data[:user_id] || data[:player_id],
      data: data,
      sequence: sequence
    })
    |> Repo.insert()
  end

  @doc """
  Lists all events for a game.
  """
  def list_game_events(game_id) do
    GameEvent
    |> where([ge], ge.game_id == ^game_id)
    |> order_by([ge], asc: ge.sequence)
    |> preload(:player)
    |> Repo.all()
  end

  ## Chat Messages

  @doc """
  Sends a chat message.
  """
  def send_chat_message(game_id, user_id, message, message_type \\ "user") do
    %ChatMessage{}
    |> ChatMessage.changeset(%{
      game_id: game_id,
      user_id: user_id,
      message: message,
      message_type: message_type
    })
    |> Repo.insert()
  end

  @doc """
  Lists chat messages for a game in chronological order (oldest first).
  By default returns up to 100 messages.
  """
  def list_chat_messages(game_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    ChatMessage
    |> where([cm], cm.game_id == ^game_id)
    |> order_by([cm], [asc: cm.inserted_at])
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  ## Room Code Generation

  @doc """
  Generates a unique 6-character room code.
  Uses uppercase letters and numbers (excluding confusing characters like O, 0, I, 1).
  """
  def generate_room_code do
    # Exclude confusing characters: O, 0, I, 1
    chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" |> String.graphemes()

    code =
      1..6
      |> Enum.map(fn _ -> Enum.random(chars) end)
      |> Enum.join()

    # Ensure uniqueness
    case get_game_by_room_code(code) do
      nil -> code
      _ -> generate_room_code()  # Recursively generate if collision
    end
  end
end
