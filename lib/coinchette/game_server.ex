defmodule Coinchette.GameServer do
  @moduledoc """
  GenServer that manages a single multiplayer game instance.

  Responsibilities:
  - Maintains game state as single source of truth
  - Validates all player actions (turn ownership, legal moves)
  - Executes bots asynchronously via Process.send_after
  - Persists state to database after each action
  - Broadcasts updates via PubSub to all connected clients
  """
  use GenServer
  require Logger

  alias Coinchette.{Multiplayer, Games}
  alias Coinchette.Bots.{Basic, Bidding}

  @type player_map :: %{Games.Player.position() => user_id :: binary() | nil}

  @type state :: %{
          game_id: binary(),
          game: Games.Game.t(),
          player_map: player_map(),
          bot_positions: MapSet.t(Games.Player.position()),
          bot_timer: reference() | nil
        }

  ## Client API

  @doc """
  Starts a GameServer for a specific game.
  """
  def start_link(game_id) do
    GenServer.start_link(__MODULE__, game_id, name: via_tuple(game_id))
  end

  @doc """
  Gets the current game state.
  """
  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
  end

  @doc """
  Adds a player to the game.
  """
  def add_player(game_id, user_id, position, opts \\ []) do
    GenServer.call(via_tuple(game_id), {:add_player, user_id, position, opts})
  end

  @doc """
  Removes a player from the game.
  """
  def remove_player(game_id, user_id) do
    GenServer.call(via_tuple(game_id), {:remove_player, user_id})
  end

  @doc """
  Starts the game (transitions from waiting to bidding).
  """
  def start_game(game_id) do
    GenServer.call(via_tuple(game_id), :start_game)
  end

  @doc """
  Makes a bid during the bidding phase.
  """
  def make_bid(game_id, user_id, bid_action) do
    GenServer.call(via_tuple(game_id), {:make_bid, user_id, bid_action})
  end

  @doc """
  Plays a card during the playing phase.
  """
  def play_card(game_id, user_id, card) do
    GenServer.call(via_tuple(game_id), {:play_card, user_id, card})
  end

  @doc """
  Sends a chat message.
  """
  def send_chat(game_id, user_id, message) do
    GenServer.cast(via_tuple(game_id), {:send_chat, user_id, message})
  end

  ## Server Callbacks

  @impl true
  def init(game_id) do
    Logger.info("Starting GameServer for game #{game_id}")

    # Load game from database
    db_game = Multiplayer.get_game!(game_id)

    # Initialize or load game state
    game =
      case Multiplayer.Game.decode_game_state(db_game.state) do
        nil ->
          # New game - initialize
          Games.Game.new(dealer_position: 0)

        existing_game ->
          existing_game
      end

    # Build player map and bot positions from database
    {player_map, bot_positions} = build_player_data(game_id)

    state = %{
      game_id: game_id,
      game: game,
      player_map: player_map,
      bot_positions: bot_positions,
      bot_timer: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:add_player, user_id, position, opts}, _from, state) do
    is_bot = Keyword.get(opts, :bot, false)
    bot_difficulty = Keyword.get(opts, :difficulty, "easy")

    result =
      if is_bot do
        Multiplayer.add_bot(state.game_id, position, bot_difficulty)
      else
        Multiplayer.add_player(state.game_id, user_id, position)
      end

    case result do
      {:ok, _player} ->
        # Update player map and bot positions
        new_player_map = Map.put(state.player_map, position, user_id)
        new_bot_positions =
          if is_bot do
            MapSet.put(state.bot_positions, position)
          else
            state.bot_positions
          end

        new_state = %{state | player_map: new_player_map, bot_positions: new_bot_positions}

        # Broadcast player joined
        broadcast_event(state.game_id, {:player_joined, %{user_id: user_id, position: position, is_bot: is_bot}})

        {:reply, :ok, new_state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:remove_player, user_id}, _from, state) do
    case Multiplayer.remove_player(state.game_id, user_id) do
      {:ok, _} ->
        # Find position of removed player
        {removed_pos, _} =
          Enum.find(state.player_map, fn {_pos, uid} -> uid == user_id end) || {nil, nil}

        # Update player map and bot positions
        new_player_map =
          state.player_map
          |> Enum.reject(fn {_pos, uid} -> uid == user_id end)
          |> Enum.into(%{})

        new_bot_positions =
          if removed_pos do
            MapSet.delete(state.bot_positions, removed_pos)
          else
            state.bot_positions
          end

        new_state = %{state | player_map: new_player_map, bot_positions: new_bot_positions}

        # Broadcast player left
        broadcast_event(state.game_id, {:player_left, %{user_id: user_id}})

        {:reply, :ok, new_state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:start_game, _from, state) do
    # Get all players from database
    db_players = Multiplayer.list_game_players(state.game_id)

    if length(db_players) < 2 do
      {:reply, {:error, :not_enough_players}, state}
    else
      # Deal initial cards and start bidding phase
      # The deal_initial_cards function creates all 4 players automatically
      game = Games.Game.deal_initial_cards(state.game)

      # Persist to database
      Multiplayer.update_game_state(state.game_id, game)
      Multiplayer.update_game_status(state.game_id, "playing", %{started_at: NaiveDateTime.utc_now()})
      Multiplayer.add_game_event(state.game_id, "game_started", %{})

      new_state = %{state | game: game}

      # Broadcast game started
      broadcast_game_update(state.game_id, game)
      broadcast_event(state.game_id, {:game_started, game})
      broadcast_system_message(state.game_id, "🎮 La partie commence !")

      # Schedule bot turn if first player is a bot (bidding phase)
      new_state = maybe_schedule_bot_turn(new_state)

      {:reply, {:ok, game}, new_state}
    end
  end

  @impl true
  def handle_call({:make_bid, user_id, bid_action}, _from, state) do
    with :ok <- validate_turn(state, user_id),
         {:ok, new_game} <- Games.Game.make_bid(state.game, bid_action) do

      # Auto-complete deal and announcements if bidding is done
      new_game =
        cond do
          new_game.status == :bidding_completed ->
            Logger.info("Bidding completed for game #{state.game_id}, completing deal and announcements")
            # Complete the deal (distribute remaining cards)
            game_with_cards = Games.Game.complete_deal(new_game)
            Logger.info("Deal completed, status: #{game_with_cards.status}")
            # Complete announcements (transition to :playing)
            final_game = Games.Game.complete_announcements(game_with_cards)
            Logger.info("Announcements completed, status: #{final_game.status}")
            final_game

          new_game.status == :bidding_failed ->
            # Send system message about failed bidding and schedule redeal
            broadcast_system_message(state.game_id, "Tous ont passé ! Redistribution dans 2 secondes...")
            Process.send_after(self(), :redeal_cards, 2000)
            new_game

          true ->
            new_game
        end

      # Persist
      Multiplayer.update_game_state(state.game_id, new_game)
      Multiplayer.add_game_event(state.game_id, "bid_made", %{
        user_id: user_id,
        bid: bid_action,
        position: current_player_position(state.game)
      })

      new_state = %{state | game: new_game}

      # Broadcast
      broadcast_game_update(state.game_id, new_game)
      broadcast_event(state.game_id, {:bid_made, %{user_id: user_id, bid: bid_action}})

      # Schedule bot turn if needed
      new_state = maybe_schedule_bot_turn(new_state)

      {:reply, {:ok, new_game}, new_state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:play_card, user_id, card}, _from, state) do
    with :ok <- validate_turn(state, user_id),
         {:ok, new_game} <- Games.Game.play_card(state.game, card) do

      # Persist
      Multiplayer.update_game_state(state.game_id, new_game)
      Multiplayer.add_game_event(state.game_id, "card_played", %{
        user_id: user_id,
        card: card_to_string(card),
        position: current_player_position(state.game)
      })

      # Check if game is finished
      new_state = %{state | game: new_game}
      new_state = maybe_handle_game_finish(new_state)

      # Broadcast
      broadcast_game_update(state.game_id, new_game)
      broadcast_event(state.game_id, {:card_played, %{user_id: user_id, card: card}})

      # Schedule bot turn if needed
      new_state = maybe_schedule_bot_turn(new_state)

      {:reply, {:ok, new_game}, new_state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_cast({:send_chat, user_id, message}, state) do
    Multiplayer.send_chat_message(state.game_id, user_id, message, "user")
    broadcast_event(state.game_id, {:chat_message, %{user_id: user_id, message: message}})
    {:noreply, state}
  end

  @impl true
  def handle_info(:play_bot_turn, state) do
    current_pos = current_player_position(state.game)
    is_bot = MapSet.member?(state.bot_positions, current_pos)

    if is_bot do
      # Execute bot logic based on game status
      result =
        case state.game.status do
          :bidding ->
            # Bot makes a bid using intelligent strategy
            bot_action = decide_bot_bid(state.game)
            Logger.info("Bot at position #{current_pos} decides: #{inspect(bot_action)}")
            Games.Game.make_bid(state.game, bot_action)

          :playing ->
            # Bot plays a card
            Games.Game.play_bot_turn(state.game, Basic)

          _ ->
            {:ok, state.game}
        end

      case result do
        {:ok, new_game} ->
          # Auto-complete deal and announcements if bidding is done
          new_game =
            cond do
              new_game.status == :bidding_completed ->
                Logger.info("Bot completed bidding for game #{state.game_id}, completing deal and announcements")
                # Complete the deal (distribute remaining cards)
                game_with_cards = Games.Game.complete_deal(new_game)
                # Complete announcements (transition to :playing)
                final_game = Games.Game.complete_announcements(game_with_cards)
                Logger.info("Bot turn: announcements completed, status: #{final_game.status}")
                final_game

              new_game.status == :bidding_failed ->
                # Send system message about failed bidding and schedule redeal
                broadcast_system_message(state.game_id, "Tous ont passé ! Redistribution dans 2 secondes...")
                Process.send_after(self(), :redeal_cards, 2000)
                new_game

              true ->
                new_game
            end

          # Persist
          Multiplayer.update_game_state(state.game_id, new_game)

          event_type = if state.game.status == :bidding, do: "bid_made", else: "card_played"
          Multiplayer.add_game_event(state.game_id, event_type, %{
            position: current_pos,
            is_bot: true
          })

          # Check if game is finished
          new_state = %{state | game: new_game, bot_timer: nil}
          new_state = maybe_handle_game_finish(new_state)

          # Broadcast
          broadcast_game_update(state.game_id, new_game)

          # Schedule next bot turn if needed
          new_state = maybe_schedule_bot_turn(new_state)

          {:noreply, new_state}

        {:error, reason} ->
          Logger.error("Bot turn failed: #{inspect(reason)}")
          {:noreply, %{state | bot_timer: nil}}
      end
    else
      {:noreply, %{state | bot_timer: nil}}
    end
  end

  @impl true
  def handle_info(:shutdown, state) do
    Logger.info("Shutting down GameServer for game #{state.game_id}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:redeal_cards, state) do
    # Redeal cards when bidding failed (all players passed)
    Logger.info("Redealing cards for game #{state.game_id} after bidding failure")

    # Rotate dealer position
    new_dealer = rem(state.game.dealer_position + 1, 4)

    # Create fresh game with new dealer and redeal cards
    new_game =
      Games.Game.new(dealer_position: new_dealer)
      |> Games.Game.deal_initial_cards()

    # Persist
    Multiplayer.update_game_state(state.game_id, new_game)
    Multiplayer.add_game_event(state.game_id, "cards_redealt", %{dealer_position: new_dealer})

    new_state = %{state | game: new_game}

    # Broadcast
    broadcast_game_update(state.game_id, new_game)
    broadcast_system_message(state.game_id, "🔄 Nouvelles cartes distribuées !")

    # Schedule bot turn if first player is a bot
    new_state = maybe_schedule_bot_turn(new_state)

    {:noreply, new_state}
  end

  ## Private Functions

  # Détermine l'action de bidding du bot en fonction de sa main
  defp decide_bot_bid(%Games.Game{bidding: bidding, players: players, current_player_position: pos}) when bidding != nil do
    current_player = Enum.at(players, pos)
    proposed_trump = bidding.proposed_trump
    round = bidding.round

    Bidding.decide_bid(current_player.hand, proposed_trump, round: round)
  end

  # Fallback si pas de bidding en cours (ne devrait pas arriver)
  defp decide_bot_bid(_game), do: :pass

  defp via_tuple(game_id) do
    {:via, Registry, {Coinchette.GameRegistry, game_id}}
  end

  defp build_player_data(game_id) do
    players = Multiplayer.list_game_players(game_id)

    player_map =
      players
      |> Enum.map(fn player -> {player.position, player.user_id} end)
      |> Enum.into(%{})

    bot_positions =
      players
      |> Enum.filter(& &1.is_bot)
      |> Enum.map(& &1.position)
      |> MapSet.new()

    {player_map, bot_positions}
  end

  defp validate_turn(state, user_id) do
    current_pos = current_player_position(state.game)
    expected_user = Map.get(state.player_map, current_pos)

    if expected_user == user_id do
      :ok
    else
      {:error, :not_your_turn}
    end
  end

  defp current_player_position(%Games.Game{status: :bidding, bidding: bidding}) when bidding != nil do
    bidding.current_bidder
  end

  defp current_player_position(%Games.Game{current_player_position: pos}) do
    pos
  end

  defp maybe_schedule_bot_turn(state) do
    # Cancel existing timer if any
    if state.bot_timer do
      Process.cancel_timer(state.bot_timer)
    end

    current_pos = current_player_position(state.game)
    is_bot = MapSet.member?(state.bot_positions, current_pos)

    # Only schedule if game is in progress and current player is a bot
    if is_bot && state.game.status in [:bidding, :playing] do
      # Schedule bot turn after 800ms (non-blocking)
      timer = Process.send_after(self(), :play_bot_turn, 800)
      %{state | bot_timer: timer}
    else
      %{state | bot_timer: nil}
    end
  end

  defp maybe_handle_game_finish(state) do
    if state.game.status == :finished do
      # Get winner and scores
      winner_team = get_winner_team(state.game)
      scores = state.game.scores

      # Update database
      Multiplayer.update_game_status(state.game_id, "finished", %{
        winner_team: winner_team,
        scores: scores,
        finished_at: NaiveDateTime.utc_now()
      })

      Multiplayer.add_game_event(state.game_id, "game_finished", %{
        winner_team: winner_team,
        scores: scores
      })

      # Broadcast
      broadcast_event(state.game_id, {:game_finished, %{winner_team: winner_team, scores: scores}})
      broadcast_system_message(state.game_id, "🏆 Partie terminée ! L'Équipe #{winner_team + 1} remporte la victoire avec #{scores[winner_team]} points !")

      # Schedule shutdown after 5 minutes
      Process.send_after(self(), :shutdown, 300_000)
    end

    state
  end

  defp get_winner_team(%Games.Game{scores: scores}) do
    Enum.max_by(scores, fn {_team, score} -> score end) |> elem(0)
  end

  defp broadcast_game_update(game_id, game) do
    Phoenix.PubSub.broadcast(
      Coinchette.PubSub,
      "game:#{game_id}",
      {:game_updated, game}
    )
  end

  defp broadcast_event(game_id, event) do
    Phoenix.PubSub.broadcast(
      Coinchette.PubSub,
      "game:#{game_id}",
      event
    )
  end

  defp broadcast_system_message(game_id, message) do
    Phoenix.PubSub.broadcast(
      Coinchette.PubSub,
      "game:#{game_id}",
      {:system_message, message}
    )
  end

  defp card_to_string(%Games.Card{rank: rank, suit: suit}) do
    "#{rank}_#{suit}"
  end
end
