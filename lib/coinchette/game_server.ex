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

  alias Coinchette.{Multiplayer, Games, Accounts}
  alias Coinchette.Bots.{Basic, Bidding}
  alias Coinchette.Notifications.GameNotifications

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
  Returns nil if the GameServer is not available.
  """
  def get_state(game_id) do
    try do
      GenServer.call(via_tuple(game_id), :get_state)
    catch
      :exit, {:noproc, _} ->
        Logger.warning("GameServer not found for game_id: #{game_id}")
        nil

      :exit, reason ->
        Logger.error("GameServer call failed for game_id #{game_id}: #{inspect(reason)}")
        nil
    end
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

  @doc """
  Deletes a game (only if in waiting status).
  """
  def delete_game(game_id, user_id) do
    GenServer.call(via_tuple(game_id), {:delete_game, user_id})
  end

  @doc """
  Changes a player's position (only in waiting status).
  """
  def change_player_position(game_id, current_position, new_position) do
    GenServer.call(via_tuple(game_id), {:change_player_position, current_position, new_position})
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
        broadcast_event(
          state.game_id,
          {:player_joined, %{user_id: user_id, position: position, is_bot: is_bot}}
        )

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

    # Auto-fill empty positions with bots
    occupied_positions = Enum.map(db_players, & &1.position) |> MapSet.new()
    empty_positions = Enum.filter(0..3, fn pos -> !MapSet.member?(occupied_positions, pos) end)

    # Add bots to empty positions
    Enum.each(empty_positions, fn position ->
      Multiplayer.add_bot(state.game_id, position, "easy")
    end)

    # Reload player data after adding bots
    {new_player_map, new_bot_positions} = build_player_data(state.game_id)

    # Deal initial cards and start bidding phase
    # The deal_initial_cards function creates all 4 players automatically
    game = Games.Game.deal_initial_cards(state.game)

    # Persist to database
    Multiplayer.update_game_state(state.game_id, game)

    Multiplayer.update_game_status(state.game_id, "playing", %{
      started_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })

    Multiplayer.add_game_event(state.game_id, "game_started", %{})

    new_state = %{
      state
      | game: game,
        player_map: new_player_map,
        bot_positions: new_bot_positions
    }

    # Broadcast game started
    broadcast_game_update(state.game_id, game)
    broadcast_event(state.game_id, {:game_started, game})
    broadcast_system_message(state.game_id, "🎮 La partie commence !")

    # Schedule bot turn if first player is a bot (bidding phase)
    new_state = maybe_schedule_bot_turn(new_state)

    {:reply, {:ok, game}, new_state}
  end

  @impl true
  def handle_call({:delete_game, user_id}, _from, state) do
    case Multiplayer.delete_game(state.game_id, user_id) do
      {:ok, _game} ->
        # Broadcast game deleted event
        broadcast_event(state.game_id, {:game_deleted, %{}})

        # Stop the server
        {:stop, :normal, :ok, state}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:change_player_position, current_position, new_position}, _from, state) do
    if state.game.status != :waiting do
      {:reply, {:error, :game_already_started}, state}
    else
      case Multiplayer.change_player_position(state.game_id, current_position, new_position) do
        {:ok, _updated_player} ->
          # Reload game data
          {new_player_map, new_bot_positions} = build_player_data(state.game_id)
          new_state = %{state | player_map: new_player_map, bot_positions: new_bot_positions}

          # Broadcast update
          broadcast_event(
            state.game_id,
            {:player_moved, %{current_position: current_position, new_position: new_position}}
          )

          {:reply, :ok, new_state}

        error ->
          {:reply, error, state}
      end
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
            Logger.info(
              "Bidding completed for game #{state.game_id}, completing deal and announcements"
            )

            # Complete the deal (distribute remaining cards)
            game_with_cards = Games.Game.complete_deal(new_game)
            Logger.info("Deal completed, status: #{game_with_cards.status}")
            # Complete announcements (transition to :playing)
            final_game = Games.Game.complete_announcements(game_with_cards)
            Logger.info("Announcements completed, status: #{final_game.status}")
            final_game

          new_game.status == :bidding_failed ->
            # Send system message about failed bidding and schedule redeal
            broadcast_system_message(
              state.game_id,
              "Tous ont passé ! Redistribution dans 2 secondes..."
            )

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

      # Notify next human player if they're not in the game
      maybe_notify_next_player(new_state)

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

      # Check if game is finished (may create new round with updated state.game)
      new_state = %{state | game: new_game}
      new_state = maybe_handle_game_finish(new_state)

      # Broadcast using state's game (which may be a new round after finish)
      broadcast_game_update(state.game_id, new_state.game)
      broadcast_event(state.game_id, {:card_played, %{user_id: user_id, card: card}})

      # Schedule bot turn if needed
      new_state = maybe_schedule_bot_turn(new_state)

      # Notify next human player if they're not in the game
      maybe_notify_next_player(new_state)

      {:reply, {:ok, new_state.game}, new_state}
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
                Logger.info(
                  "Bot completed bidding for game #{state.game_id}, completing deal and announcements"
                )

                # Complete the deal (distribute remaining cards)
                game_with_cards = Games.Game.complete_deal(new_game)
                # Complete announcements (transition to :playing)
                final_game = Games.Game.complete_announcements(game_with_cards)
                Logger.info("Bot turn: announcements completed, status: #{final_game.status}")
                final_game

              new_game.status == :bidding_failed ->
                # Send system message about failed bidding and schedule redeal
                broadcast_system_message(
                  state.game_id,
                  "Tous ont passé ! Redistribution dans 2 secondes..."
                )

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

          # Check if game is finished (may create new round with updated state.game)
          new_state = %{state | game: new_game, bot_timer: nil}
          new_state = maybe_handle_game_finish(new_state)

          # Broadcast using state's game (which may be a new round after finish)
          broadcast_game_update(state.game_id, new_state.game)

          # Schedule next bot turn if needed
          new_state = maybe_schedule_bot_turn(new_state)

          # Notify next human player if they're not in the game
          maybe_notify_next_player(new_state)

          {:noreply, new_state}

        {:error, reason} ->
          Logger.error("Bot turn failed: #{inspect(reason)}")
          {:noreply, %{state | bot_timer: nil}}
      end
    else
      {:noreply, %{state | bot_timer: nil}}
    end
  rescue
    Ecto.NoResultsError ->
      Logger.warning("Game #{state.game_id} no longer exists, stopping server")
      {:stop, :normal, state}
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
  rescue
    Ecto.NoResultsError ->
      Logger.warning("Game #{state.game_id} no longer exists, stopping server")
      {:stop, :normal, state}
  end

  ## Private Functions

  # Détermine l'action de bidding du bot en fonction de sa main
  defp decide_bot_bid(%Games.Game{
         bidding: bidding,
         players: players,
         current_player_position: pos
       })
       when bidding != nil do
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

  defp current_player_position(%Games.Game{status: :bidding, bidding: bidding})
       when bidding != nil do
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
      # Hand (round) is finished - 8 tricks completed
      # Get current hand scores
      hand_scores = state.game.scores
      hand_winner = get_winner_team(state.game)

      # Get DB game to access target_score and cumulative scores
      db_game = Multiplayer.get_game!(state.game_id)

      # Add hand scores to cumulative scores
      # DB stores scores with string keys, convert to integer keys
      existing_scores =
        if db_game.scores do
          Map.new(db_game.scores, fn {k, v} ->
            {(is_binary(k) && String.to_integer(k)) || k, v}
          end)
        else
          %{0 => 0, 1 => 0}
        end

      cumulative_scores =
        existing_scores
        |> Map.update(0, hand_scores[0], &(&1 + hand_scores[0]))
        |> Map.update(1, hand_scores[1], &(&1 + hand_scores[1]))

      # Check if any team reached target_score
      team_0_total = cumulative_scores[0]
      team_1_total = cumulative_scores[1]
      target_score = db_game.target_score

      if team_0_total >= target_score or team_1_total >= target_score do
        # Game is completely finished!
        final_winner = if team_0_total > team_1_total, do: 0, else: 1

        # Update database with final results
        Multiplayer.update_game_status(state.game_id, "finished", %{
          winner_team: final_winner,
          scores: cumulative_scores,
          finished_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        })

        Multiplayer.add_game_event(state.game_id, "game_finished", %{
          winner_team: final_winner,
          scores: cumulative_scores,
          total_rounds: db_game.round_number
        })

        # Update player statistics
        update_player_statistics(state, final_winner, cumulative_scores)

        # Broadcast
        broadcast_event(
          state.game_id,
          {:game_finished, %{winner_team: final_winner, scores: cumulative_scores}}
        )

        broadcast_system_message(
          state.game_id,
          "🏆 Partie terminée ! L'Équipe #{final_winner + 1} remporte la victoire avec #{cumulative_scores[final_winner]} points après #{db_game.round_number} manches !"
        )

        # Schedule shutdown after 5 minutes
        Process.send_after(self(), :shutdown, 300_000)

        state
      else
        # Target not reached - start a new round!
        new_round_number = db_game.round_number + 1
        new_dealer = rem(state.game.dealer_position + 1, 4)

        Multiplayer.add_game_event(state.game_id, "round_finished", %{
          round: db_game.round_number,
          hand_winner: hand_winner,
          hand_scores: hand_scores,
          cumulative_scores: cumulative_scores
        })

        # Create new game state for next round
        new_game =
          Games.Game.new(dealer_position: new_dealer)
          |> Games.Game.deal_initial_cards()

        # Persist new game state first
        Multiplayer.update_game_state(state.game_id, new_game)

        # Then update cumulative scores and round number
        # This must come AFTER update_game_state to not be overwritten
        Multiplayer.update_game_status(state.game_id, "playing", %{
          scores: cumulative_scores,
          round_number: new_round_number
        })

        # Update state
        new_state = %{state | game: new_game}

        # Broadcast round completion and new round start
        broadcast_system_message(
          state.game_id,
          "🎴 Manche #{db_game.round_number} terminée ! Équipe #{hand_winner + 1}: +#{hand_scores[hand_winner]} pts. Score: Équipe 1: #{cumulative_scores[0]} - Équipe 2: #{cumulative_scores[1]}"
        )

        broadcast_system_message(
          state.game_id,
          "🔄 Nouvelle manche #{new_round_number} ! Objectif: #{target_score} points"
        )

        # Note: game_update broadcast is handled by the caller (play_card/bot_turn)
        # to avoid double broadcast

        broadcast_event(
          state.game_id,
          {:round_finished,
           %{
             round: db_game.round_number,
             cumulative_scores: cumulative_scores,
             new_round: new_round_number
           }}
        )

        # Schedule bot turn if needed
        maybe_schedule_bot_turn(new_state)
      end
    else
      state
    end
  end

  defp update_player_statistics(state, winner_team, scores) do
    # Get all human players (non-bots)
    human_players =
      state.player_map
      |> Enum.reject(fn {position, _user_id} ->
        MapSet.member?(state.bot_positions, position)
      end)

    # Determine if this is a real multiplayer game (at least 2 human players)
    is_multiplayer = length(human_players) >= 2

    # Check if the game had Belote/Rebelote
    had_belote_rebelote = state.game.belote_rebelote != nil

    # Pre-compute ELO averages per team for multiplayer games
    team_elos =
      if is_multiplayer do
        compute_team_elos(human_players, state.bot_positions)
      else
        %{}
      end

    # Update stats for each human player
    Enum.each(human_players, fn {position, user_id} ->
      player_team = rem(position, 2)
      result = if player_team == winner_team, do: :win, else: :loss

      points_scored = Map.get(scores, player_team, 0)
      points_conceded = Map.get(scores, 1 - player_team, 0)

      player_had_belote =
        case state.game.belote_rebelote do
          {team, _} when team == player_team and had_belote_rebelote -> true
          _ -> false
        end

      game_data = %{
        points_scored: points_scored,
        points_conceded: points_conceded,
        had_belote_rebelote: player_had_belote,
        team: player_team,
        is_multiplayer: is_multiplayer,
        opponent_elo: Map.get(team_elos, 1 - player_team, 1000)
      }

      case Accounts.record_game_result(user_id, result, game_data) do
        {:ok, _stats} ->
          Logger.debug("Updated stats for user #{user_id}: #{result}")

        {:error, reason} ->
          Logger.error("Failed to update stats for user #{user_id}: #{inspect(reason)}")
      end
    end)
  end

  defp compute_team_elos(human_players, bot_positions) do
    # Group human players by team, compute average ELO per team
    human_players
    |> Enum.reject(fn {pos, _} -> MapSet.member?(bot_positions, pos) end)
    |> Enum.group_by(fn {pos, _} -> rem(pos, 2) end)
    |> Map.new(fn {team, players} ->
      elos =
        Enum.map(players, fn {_pos, user_id} ->
          case Accounts.get_stats(user_id) do
            nil -> 1000
            stats -> stats.elo_rating
          end
        end)

      avg = if elos == [], do: 1000, else: div(Enum.sum(elos), length(elos))
      {team, avg}
    end)
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

  defp maybe_notify_next_player(state) do
    current_pos = current_player_position(state.game)
    is_bot = MapSet.member?(state.bot_positions, current_pos)

    if !is_bot && state.game.status in [:bidding, :playing] do
      user_id = Map.get(state.player_map, current_pos)

      if user_id do
        # Check if user is present in the game
        present_users =
          CoinchetteWeb.Presence.list("game:#{state.game_id}")
          |> Map.keys()
          |> MapSet.new()

        unless MapSet.member?(present_users, user_id) do
          GameNotifications.notify_your_turn(user_id, "Coinchette", state.game_id)
        end
      end
    end
  end

  defp card_to_string(%Games.Card{rank: rank, suit: suit}) do
    "#{rank}_#{suit}"
  end
end
