defmodule CoinchetteWeb.MultiplayerGameLive do
  use CoinchetteWeb, :live_view

  alias Coinchette.{Multiplayer, GameServer}
  alias Coinchette.Games.{Game, Card}
  alias CoinchetteWeb.Presence

  on_mount {CoinchetteWeb.Auth, :ensure_authenticated}

  def mount(%{"id" => game_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to game updates
      Phoenix.PubSub.subscribe(Coinchette.PubSub, "game:#{game_id}")

      # Track user presence in this game
      {:ok, _} =
        Presence.track(self(), "game:#{game_id}", socket.assigns.current_user.id, %{
          username: socket.assigns.current_user.username,
          joined_at: System.system_time(:second)
        })
    end

    # Ensure GameServer is running, start it if needed
    case Coinchette.GameServerSupervisor.start_game(game_id) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      {:error, reason} ->
        require Logger
        Logger.error("Failed to start GameServer for game #{game_id}: #{inspect(reason)}")
    end

    # Get game state from GameServer (with fallback)
    case GameServer.get_state(game_id) do
      nil ->
        # GameServer not available, redirect to lobby
        socket =
          socket
          |> put_flash(:error, "Cette partie n'est plus disponible")
          |> push_navigate(to: ~p"/lobby")

        {:ok, socket}

      state ->
        game = state.game

        # Load DB game to get cumulative scores, target_score, and round_number
        db_game = Multiplayer.get_game!(game_id)

        # Always rebuild player data to ensure consistency
        # build_player_data always returns {%{}, MapSet.new()}
        {player_map, bot_positions} = build_player_data(game_id)

        # Find user's position
        my_position = find_user_position(player_map, socket.assigns.current_user.id)

        # Load chat messages and set up stream
        chat_messages = Multiplayer.list_chat_messages(game_id)

        # Get list of present users
        present_users = get_present_users(game_id)

        socket =
          socket
          |> assign(:page_title, "Playing Game")
          |> assign(:game, game)
          |> assign(:db_game, db_game)
          |> assign(:game_id, game_id)
          |> assign(:my_position, my_position)
          |> assign(:player_map, player_map)
          |> assign(:bot_positions, bot_positions)
          |> assign(:selected_card, nil)
          |> assign(:message, get_game_message(game, my_position))
          |> assign(:belote_announcement, nil)
          |> assign(:present_users, present_users)
          |> stream(:chat_messages, chat_messages)
          |> load_player_names(game_id)

        {:ok, socket}
    end
  end

  ## Event Handlers - User Actions

  def handle_event("play_card", %{"card" => card_id}, socket) do
    if is_my_turn?(socket) do
      [rank_str, suit_str] = String.split(card_id, "_")
      rank = String.to_existing_atom(rank_str)
      suit = String.to_existing_atom(suit_str)
      card = Card.new(rank, suit)

      case GameServer.play_card(socket.assigns.game_id, socket.assigns.current_user.id, card) do
        {:ok, _game} ->
          # Play card sound and haptic feedback
          socket =
            socket
            |> push_event("play-sound", %{sound: "cardPlay"})
            |> push_event("haptic-feedback", %{pattern: "cardPlay"})

          # State will update via PubSub
          {:noreply, socket}

        {:error, :not_your_turn} ->
          {:noreply, put_flash(socket, :error, "Ce n'est pas votre tour")}

        {:error, :invalid_card} ->
          {:noreply, put_flash(socket, :error, "Carte invalide selon les règles FFB")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Erreur: #{inspect(reason)}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("bid_take", _params, socket) do
    if is_my_turn?(socket) do
      case GameServer.make_bid(socket.assigns.game_id, socket.assigns.current_user.id, :take) do
        {:ok, _game} ->
          socket =
            socket
            |> push_event("play-sound", %{sound: "bidTake"})
            |> push_event("haptic-feedback", %{pattern: "bidTake"})

          {:noreply, socket}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Erreur: #{inspect(reason)}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("bid_pass", _params, socket) do
    if is_my_turn?(socket) do
      case GameServer.make_bid(socket.assigns.game_id, socket.assigns.current_user.id, :pass) do
        {:ok, _game} ->
          socket =
            socket
            |> push_event("play-sound", %{sound: "bidPass"})
            |> push_event("haptic-feedback", %{pattern: "bidPass"})

          {:noreply, socket}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Erreur: #{inspect(reason)}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("bid_choose", %{"suit" => suit_str}, socket) do
    if is_my_turn?(socket) do
      suit = String.to_existing_atom(suit_str)

      case GameServer.make_bid(
             socket.assigns.game_id,
             socket.assigns.current_user.id,
             {:choose, suit}
           ) do
        {:ok, _game} ->
          socket =
            socket
            |> push_event("play-sound", %{sound: "bidTake"})
            |> push_event("haptic-feedback", %{pattern: "bidTake"})

          {:noreply, socket}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Erreur: #{inspect(reason)}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("leave_game", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/lobby")}
  end

  def handle_event("send_chat", %{"message" => message}, socket) do
    message = String.trim(message)

    if message != "" do
      GameServer.send_chat(
        socket.assigns.game_id,
        socket.assigns.current_user.id,
        message
      )
    end

    # Clear the input field after sending
    {:noreply, push_event(socket, "clear-chat-input", %{})}
  end

  ## PubSub Event Handlers

  def handle_info({:game_updated, game}, socket) do
    old_game = socket.assigns.game

    # Reload DB game to get updated cumulative scores and round number
    db_game = Multiplayer.get_game!(socket.assigns.game_id)

    # Detect belote announcement
    announcement = detect_belote_announcement(old_game, game)

    # Detect game events and play sounds
    socket =
      socket
      |> play_game_sounds(old_game, game)
      |> play_belote_sound(announcement)
      |> assign(:game, game)
      |> assign(:db_game, db_game)
      |> assign(:message, get_game_message(game, socket.assigns.my_position))
      |> assign(:belote_announcement, announcement)

    {:noreply, socket}
  end

  def handle_info({:card_played, _data}, socket) do
    # Game update will come via :game_updated
    {:noreply, socket}
  end

  def handle_info({:bid_made, _data}, socket) do
    # Game update will come via :game_updated
    {:noreply, socket}
  end

  def handle_info({:game_finished, _data}, socket) do
    # Game update will come via :game_updated
    {:noreply, socket}
  end

  def handle_info({:chat_message, %{user_id: user_id, message: text}}, socket) do
    # Load user info and create message struct
    user = Coinchette.Accounts.get_user!(user_id)

    chat_message = %{
      id: Ecto.UUID.generate(),
      user: user,
      message: text,
      message_type: "user",
      inserted_at: DateTime.utc_now()
    }

    {:noreply, stream_insert(socket, :chat_messages, chat_message)}
  end

  def handle_info({:system_message, message}, socket) do
    # Add system message
    chat_message = %{
      id: Ecto.UUID.generate(),
      user: %{username: "Système"},
      message: message,
      message_type: "system",
      inserted_at: DateTime.utc_now()
    }

    {:noreply, stream_insert(socket, :chat_messages, chat_message)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    # Update the list of present users when someone joins/leaves
    present_users = get_present_users(socket.assigns.game_id)
    {:noreply, assign(socket, :present_users, present_users)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  ## Helper Functions

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

  defp find_user_position(player_map, user_id) do
    Enum.find_value(player_map, fn {pos, uid} -> if uid == user_id, do: pos end)
  end

  defp is_my_turn?(socket) do
    game = socket.assigns.game
    my_position = socket.assigns.my_position

    current_pos =
      case game.status do
        :bidding when game.bidding != nil -> game.bidding.current_bidder
        _ -> game.current_player_position
      end

    current_pos == my_position
  end

  defp load_player_names(socket, game_id) do
    players = Multiplayer.list_game_players(game_id)

    player_names =
      players
      |> Enum.map(fn p ->
        name =
          if p.is_bot do
            bot_name(p.position, p.bot_difficulty)
          else
            p.user.username
          end

        {p.position, name}
      end)
      |> Enum.into(%{})

    assign(socket, :player_names, player_names)
  end

  defp get_present_users(game_id) do
    Presence.list("game:#{game_id}")
    |> Map.keys()
    |> MapSet.new()
  end

  # Generate unique bot names based on position and difficulty
  defp bot_name(position, difficulty) do
    # French-themed bot names
    names = ["Marcel", "Josette", "René", "Ginette", "Robert", "Simone", "André", "Yvette"]
    base_name = Enum.at(names, rem(position, length(names)))

    case difficulty do
      "easy" -> "#{base_name} 🐌"
      "medium" -> "#{base_name} ⚡"
      "hard" -> "#{base_name} 🔥"
      _ -> base_name
    end
  end

  defp get_player_name(socket_or_map, position) do
    player_names =
      case socket_or_map do
        %{assigns: %{player_names: names}} -> names
        %{} = names when is_map(names) -> names
      end

    Map.get(player_names, position, "Joueur #{position + 1}")
  end

  # Sound Effects Helpers

  defp play_game_sounds(socket, old_game, new_game) do
    socket
    |> play_shuffle_sound(old_game, new_game)
    |> play_trick_win_sound(old_game, new_game)
    |> play_victory_sound(old_game, new_game)
    |> play_announcement_sound(old_game, new_game)
  end

  defp play_shuffle_sound(socket, old_game, new_game) do
    # Play shuffle when cards are dealt (transition to bidding or playing)
    if (old_game.status == :waiting && new_game.status in [:bidding, :playing]) ||
         (old_game.status == :bidding_failed && new_game.status == :bidding) do
      push_event(socket, "play-sound", %{sound: "cardShuffle"})
    else
      socket
    end
  end

  defp play_trick_win_sound(socket, old_game, new_game) do
    # Play trick win sound and haptic when a trick is completed
    if length(new_game.tricks_won) > length(old_game.tricks_won) do
      socket
      |> push_event("play-sound", %{sound: "trickWin"})
      |> push_event("haptic-feedback", %{pattern: "trickWin"})
    else
      socket
    end
  end

  defp play_victory_sound(socket, old_game, new_game) do
    # Play victory/defeat sound, haptic, and confetti when game finishes
    if !Game.game_over?(old_game) && Game.game_over?(new_game) do
      my_position = socket.assigns.my_position
      my_team = if my_position in [0, 2], do: 0, else: 1
      winner_team = Game.winner(new_game)

      is_winner = winner_team == my_team
      pattern = if is_winner, do: "victory", else: "defeat"

      socket =
        socket
        |> push_event("play-sound", %{sound: pattern})
        |> push_event("haptic-feedback", %{pattern: pattern})

      # Launch confetti only for winners
      if is_winner do
        # Determine confetti type based on score difference
        my_team_score = Enum.at(new_game.scores, my_team)
        other_team_score = Enum.at(new_game.scores, 1 - my_team)
        score_diff = my_team_score - other_team_score

        confetti_type =
          cond do
            # Perfect game
            my_team_score == 162 -> "perfect"
            # Dominating win
            score_diff >= 100 -> "big_win"
            # Standard win
            true -> "victory"
          end

        push_event(socket, "confetti", %{type: confetti_type})
      else
        socket
      end
    else
      socket
    end
  end

  defp play_announcement_sound(socket, old_game, new_game) do
    # Play announcement sound when announcements are revealed
    if old_game.announcements_result == nil &&
         new_game.announcements_result != nil &&
         new_game.announcements_result.total_points > 0 do
      push_event(socket, "play-sound", %{sound: "announcement"})
    else
      socket
    end
  end

  defp play_belote_sound(socket, announcement) do
    # Play belote sound when belote/rebelote is announced
    case announcement do
      {:belote, _team} ->
        push_event(socket, "play-sound", %{sound: "belote"})

      {:rebelote, _team} ->
        push_event(socket, "play-sound", %{sound: "belote"})

      nil ->
        socket
    end
  end

  defp detect_belote_announcement(old_game, new_game) do
    cond do
      # Belote annoncée (premier Roi ou Dame d'atout joué)
      old_game.belote_announced == nil && new_game.belote_announced != nil ->
        {pos, _card_type} = new_game.belote_announced
        player = Enum.at(new_game.players, pos)
        {:belote, player.team}

      # Rebelote (deuxième carte de la paire jouée)
      new_game.belote_rebelote != nil && old_game.belote_rebelote != nil &&
        old_game.belote_rebelote == {elem(new_game.belote_rebelote, 0), false} &&
        elem(new_game.belote_rebelote, 1) == true ->
        {team, _} = new_game.belote_rebelote
        {:rebelote, team}

      true ->
        nil
    end
  end

  defp get_game_message(game, my_position) do
    current_pos =
      case game.status do
        :bidding when game.bidding != nil -> game.bidding.current_bidder
        _ -> game.current_player_position
      end

    is_my_turn = current_pos == my_position

    cond do
      game.status == :bidding ->
        round_text = if game.bidding.round == 1, do: "Premier", else: "Second"

        if is_my_turn do
          "#{round_text} tour d'enchères - À vous de jouer"
        else
          player_name = get_player_name(%{assigns: %{player_names: %{}}}, current_pos)
          "#{round_text} tour - #{player_name} enchérit..."
        end

      game.status == :bidding_failed ->
        "Tous ont passé ! Redistribution en cours..."

      Game.game_over?(game) ->
        winner_team = Game.winner(game)
        loser_team = if winner_team == 0, do: 1, else: 0
        winner_score = game.scores[winner_team]
        loser_score = game.scores[loser_team]

        my_player = Enum.at(game.players, my_position)
        my_team = if my_player, do: my_player.team, else: 0

        if winner_team == my_team do
          "🎉 Victoire ! Votre équipe gagne #{winner_score} - #{loser_score}"
        else
          "😢 Défaite... Score final: #{game.scores[0]} - #{game.scores[1]}"
        end

      is_my_turn ->
        "Votre tour de jouer"

      true ->
        "En attente..."
    end
  end

  defp card_playable?(game, card, my_position) do
    current_player = Game.current_player(game)

    if current_player && current_player.position == my_position && game.status == :playing do
      alias Coinchette.Games.Rules

      valid_cards =
        Rules.valid_cards(
          current_player,
          game.current_trick,
          game.trump_suit,
          current_player.position
        )

      card in valid_cards
    else
      false
    end
  end

  ## Rendering

  def render(assigns) do
    ~H"""
    <div>
    <div class="min-h-screen bg-gradient-to-br from-green-800 to-green-600 p-4 sm:p-8 pb-20 sm:pb-8">
      <div class="max-w-6xl mx-auto">
        <!-- Header -->
        <div class="flex items-center justify-between mb-4 sm:mb-6">
          <div class="text-white flex-1 min-w-0">
            <!-- Masquer logo et titre sur mobile -->
            <h1 class="hidden sm:block text-2xl sm:text-4xl font-bold">🃏 Coinchette</h1>
            <!-- Message tronqué sur mobile -->
            <p class="text-green-100 text-xs sm:text-sm lg:text-lg mt-1 truncate">{@message}</p>
          </div>
          <div class="flex items-center gap-1 sm:gap-2 flex-shrink-0">
            <div class="scale-75 sm:scale-100">
              <.volume_control id="game-volume-control" class="text-white" />
            </div>
            <div class="scale-75 sm:scale-100">
              <Layouts.theme_toggle />
            </div>
            <button phx-click="leave_game" class="btn btn-ghost btn-xs sm:btn-sm text-white px-2 sm:px-4">
              <!-- Icône seule sur mobile -->
              <svg class="w-4 h-4 sm:hidden" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
              <span class="hidden sm:inline">Quitter</span>
            </button>
          </div>
        </div>
        
    <!-- Game Info Bar (Trump and Scores) -->
        <.game_info_bar game={@game} db_game={@db_game} />
        
    <!-- Belote/Rebelote Notification -->
        <%= if @belote_announcement do %>
          <.belote_notification announcement={@belote_announcement} player_names={@player_names} />
        <% end %>
        
    <!-- Announcements Notification -->
        <%= if @game.announcements_result && @game.announcements_result.total_points > 0 && length(@game.tricks_won) <= 1 do %>
          <.announcements_notification result={@game.announcements_result} />
        <% end %>
        
    <!-- Game Board with Chat (always visible) -->
        <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
          <div class="lg:col-span-3">
            <%= if @game.status == :bidding do %>
              <!-- Bidding Interface -->
              <.bidding_interface
                game={@game}
                is_my_turn={is_my_turn?(@game, @my_position)}
                player_names={@player_names}
              />
            <% end %>
            
    <!-- Game Board (always show hand) -->
            <.game_board
              game={@game}
              my_position={@my_position}
              player_names={@player_names}
              bot_positions={@bot_positions}
              player_map={@player_map}
              present_users={@present_users}
              is_my_turn={is_my_turn?(@game, @my_position)}
            />
          </div>
          
    <!-- Chat Sidebar -->
          <div class="lg:col-span-1">
            <.chat_panel streams={@streams} />
          </div>
        </div>
        
    <!-- Score Panel -->
        <.score_panel
          game={@game}
          db_game={@db_game}
          my_position={@my_position}
          player_names={@player_names}
        />
      </div>
    </div>

    <!-- Bottom Navigation (visible sur mobile uniquement) -->
    <div class="block sm:hidden">
      <CoinchetteWeb.BottomNav.bottom_nav current_path="/game" />
    </div>
    </div>
    """
  end

  ## Components

  defp belote_notification(assigns) do
    ~H"""
    <div class="alert alert-success shadow-lg mb-4 animate-pulse">
      <div class="flex items-center gap-2">
        <%= case @announcement do %>
          <% {:belote, team} -> %>
            <span class="text-2xl">👑</span>
            <div>
              <h3 class="font-bold text-lg">Belote !</h3>
              <div class="text-sm">
                <%= if team == 0 do %>
                  Annoncée par l'Équipe 1
                <% else %>
                  Annoncée par l'Équipe 2
                <% end %>
              </div>
            </div>
          <% {:rebelote, team} -> %>
            <span class="text-2xl">👸</span>
            <div>
              <h3 class="font-bold text-lg">Rebelote !</h3>
              <div class="text-sm">
                <%= if team == 0 do %>
                  Équipe 1 gagne +20 points
                <% else %>
                  Équipe 2 gagne +20 points
                <% end %>
              </div>
            </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp announcements_notification(assigns) do
    # Extract announcements from winning team
    winning_announcements =
      assigns.result.all_announcements
      |> Enum.filter(fn player_ann -> player_ann.team == assigns.result.winning_team end)
      |> Enum.flat_map(fn player_ann -> player_ann.announcements end)

    assigns = Map.put(assigns, :winning_announcements, winning_announcements)

    ~H"""
    <div class="alert alert-info shadow-lg mb-4">
      <div>
        <h3 class="font-bold text-lg">
          Annonces : +{@result.total_points} points pour l'Équipe {@result.winning_team + 1}
        </h3>
        <div class="text-sm mt-1 space-y-1">
          <%= for announcement <- @winning_announcements do %>
            <div>
              <%= case announcement.type do %>
                <% :tierce -> %>
                  Tierce : +{announcement.points} points
                <% :cinquante -> %>
                  Cinquante : +{announcement.points} points
                <% :cent -> %>
                  Cent : +{announcement.points} points
                <% :carre_jacks -> %>
                  Carré de Valets : +{announcement.points} points
                <% :carre_nines -> %>
                  Carré de 9 : +{announcement.points} points
                <% :carre_aces -> %>
                  Carré d'As : +{announcement.points} points
                <% :carre_tens -> %>
                  Carré de 10 : +{announcement.points} points
                <% :carre_kings -> %>
                  Carré de Rois : +{announcement.points} points
                <% :carre_queens -> %>
                  Carré de Dames : +{announcement.points} points
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp bidding_interface(assigns) do
    ~H"""
    <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 mb-6">
      <div class="text-center">
        <h2 class="text-2xl font-bold text-white mb-4">
          Phase d'enchères - {if @game.bidding.round == 1, do: "Premier", else: "Second"} tour
        </h2>

        <%= if @game.bidding.proposed_trump do %>
          <div class="mb-4">
            <p class="text-white/80 mb-2">Carte proposée :</p>
            <div class="flex justify-center">
              <.card_display card={@game.proposed_trump_card} />
            </div>
          </div>
        <% end %>

        <div class="flex flex-wrap justify-center gap-4 mt-6">
          <%= if @is_my_turn do %>
            <%= if @game.bidding.round == 1 do %>
              <button phx-click="bid_take" class="btn btn-success btn-lg">
                Prendre
              </button>
              <button phx-click="bid_pass" class="btn btn-error btn-lg">
                Passer
              </button>
            <% else %>
              <%= for suit <- [:spades, :hearts, :diamonds, :clubs] do %>
                <button
                  phx-click="bid_choose"
                  phx-value-suit={suit}
                  class="btn btn-primary"
                >
                  {suit_symbol(suit)} {suit_name(suit)}
                </button>
              <% end %>
              <button phx-click="bid_pass" class="btn btn-error">
                Passer
              </button>
            <% end %>
          <% else %>
            <div class="text-white/60">
              En attente de {Map.get(@player_names, @game.bidding.current_bidder, "Joueur")}...
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp game_board(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Trick Area and Hand -->
      <div class="lg:col-span-2">
        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6">
          <!-- Trick Area -->
          <%= if @game.current_trick && length(@game.current_trick.cards) > 0 do %>
            <div class="relative aspect-square max-w-md mx-auto mb-6">
              <div class="absolute inset-0 bg-green-700/50 rounded-full border-4 border-white/20">
              </div>
              <%= for {card, pos} <- @game.current_trick.cards do %>
                <.trick_card
                  card={card}
                  position={pos}
                  my_position={@my_position}
                  player_name={get_player_name(@player_names, pos)}
                />
              <% end %>
            </div>
          <% end %>
          
    <!-- Player Hand -->
          <%= if @my_position != nil do %>
            <% my_player = Enum.at(@game.players, @my_position) %>
            <%= if my_player do %>
              <div class="mt-6">
                <h3 class="text-white font-semibold mb-3 text-center">Votre main</h3>
                <div class="flex flex-wrap justify-center gap-2">
                  <%= for card <- my_player.hand do %>
                    <% playable = card_playable?(@game, card, @my_position) %>
                    <button
                      phx-click={playable && @is_my_turn && "play_card"}
                      phx-value-card={"#{card.rank}_#{card.suit}"}
                      disabled={!playable || !@is_my_turn}
                      class={[
                        "transition-all duration-200",
                        playable && @is_my_turn && "hover:scale-110 cursor-pointer",
                        !playable && "opacity-50 cursor-not-allowed"
                      ]}
                    >
                      <.card_display card={card} />
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
      
    <!-- Players Info -->
      <div class="lg:col-span-1">
        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-4">
          <h3 class="text-white font-semibold mb-4">Joueurs</h3>
          <div class="space-y-3">
            <%= for player <- @game.players do %>
              <% is_current = player.position == @game.current_player_position %>
              <% is_me = player.position == @my_position %>
              <% is_bot = MapSet.member?(@bot_positions, player.position) %>
              <% user_id = Map.get(@player_map, player.position) %>
              <% is_connected = is_bot || MapSet.member?(@present_users, user_id) %>
              <% is_taker =
                @game.trump_suit && @game.bidding && @game.bidding.taker == player.position %>
              <div class={[
                "p-3 rounded-lg",
                is_current && "bg-yellow-500/30 ring-2 ring-2 ring-yellow-400",
                !is_current && "bg-white/5",
                is_me && "ring-2 ring-blue-400"
              ]}>
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <div
                      class={[
                        "w-2 h-2 rounded-full flex-shrink-0",
                        is_connected && "bg-green-400",
                        !is_connected && "bg-red-400 animate-pulse"
                      ]}
                      title={(is_connected && "Connecté") || "Déconnecté"}
                    />
                    <div class="flex-1">
                      <div class="text-white font-medium flex items-center gap-2 flex-wrap">
                        {Map.get(@player_names, player.position, "Joueur #{player.position + 1}")}
                        <%= if is_me do %>
                          <span class="badge badge-sm badge-primary">Vous</span>
                        <% end %>
                        <%= if !is_connected && !is_bot do %>
                          <span class="badge badge-sm badge-error">Déco</span>
                        <% end %>
                        <%= if is_taker do %>
                          <span class="badge badge-sm badge-success gap-1">
                            <span>A pris</span>
                            <span class="text-base">{suit_symbol(@game.trump_suit)}</span>
                          </span>
                        <% end %>
                      </div>
                      <div class="text-white/60 text-sm">
                        Équipe {player.team + 1} • {length(player.hand)} cartes
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp game_info_bar(assigns) do
    # Convert cumulative scores from string keys to integers
    cumulative_scores =
      if assigns.db_game.scores do
        %{
          0 => Map.get(assigns.db_game.scores, "0", 0),
          1 => Map.get(assigns.db_game.scores, "1", 0)
        }
      else
        %{0 => 0, 1 => 0}
      end

    assigns = assign(assigns, :cumulative_scores, cumulative_scores)

    ~H"""
    <div class="mb-4 bg-white/10 backdrop-blur-sm rounded-lg p-4">
      <!-- Round Info and Target -->
      <div class="flex items-center justify-center gap-4 mb-3 text-white/80 text-sm">
        <span>Manche {@db_game.round_number}</span>
        <span>•</span>
        <span>Objectif: {@db_game.target_score} points</span>
      </div>

      <div class="flex flex-wrap items-center justify-between gap-4">
        <!-- Trump Display -->
        <%= if @game.trump_suit do %>
          <div class="flex items-center gap-2">
            <span class="text-white/80 text-sm font-medium">Atout:</span>
            <span class="text-2xl font-bold text-white">
              {suit_symbol(@game.trump_suit)} {suit_name(@game.trump_suit)}
            </span>
          </div>
        <% end %>

    <!-- Scores: Cumulative (Total) and Current Hand -->
        <div class="flex gap-6 text-center">
          <div>
            <div class="text-white/80 text-xs mb-1">Équipe 1</div>
            <!-- Cumulative Score (larger) -->
            <div class="text-2xl font-bold text-white">
              {@cumulative_scores[0]}
            </div>
            <!-- Current Hand Score (smaller) -->
            <div class="text-white/60 text-xs">
              Manche: {@game.scores[0]} pts
            </div>
            <div class="text-white/60 text-xs">
              {Enum.count(@game.tricks_won, fn {team, _} -> team == 0 end)} plis
            </div>
          </div>
          <div>
            <div class="text-white/80 text-xs mb-1">Équipe 2</div>
            <!-- Cumulative Score (larger) -->
            <div class="text-2xl font-bold text-white">
              {@cumulative_scores[1]}
            </div>
            <!-- Current Hand Score (smaller) -->
            <div class="text-white/60 text-xs">
              Manche: {@game.scores[1]} pts
            </div>
            <div class="text-white/60 text-xs">
              {Enum.count(@game.tricks_won, fn {team, _} -> team == 1 end)} plis
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp score_panel(assigns) do
    # Convert cumulative scores from string keys to integers for final display
    cumulative_scores =
      if assigns.db_game.scores do
        %{
          0 => Map.get(assigns.db_game.scores, "0", 0),
          1 => Map.get(assigns.db_game.scores, "1", 0)
        }
      else
        %{0 => 0, 1 => 0}
      end

    assigns = assign(assigns, :cumulative_scores, cumulative_scores)

    ~H"""
    <div class="mt-6 bg-white/10 backdrop-blur-sm rounded-lg p-6">
      <!-- Last Trick Display -->
      <%= if length(@game.tricks_won) > 0 do %>
        <div class="mb-6">
          <h3 class="text-white/80 text-sm font-semibold mb-3 text-center">Dernier pli</h3>
          <.last_trick_display game={@game} my_position={@my_position} player_names={@player_names} />
        </div>
      <% end %>

    <!-- Final Scores (shown when game is finished) -->
      <%= if @db_game.status == "finished" do %>
        <div class="text-center">
          <h3 class="text-white text-xl font-bold mb-2">🏆 Partie terminée !</h3>
          <p class="text-white/80 text-sm mb-4">
            Après {@db_game.round_number} manche(s)
          </p>
          <div class="grid grid-cols-2 gap-6">
            <div>
              <h4 class="text-white/80 text-sm mb-2">Équipe 1</h4>
              <div class="text-4xl font-bold text-white">
                {@cumulative_scores[0]}
              </div>
              <div class="text-white/60 text-xs mt-1">points</div>
            </div>
            <div>
              <h4 class="text-white/80 text-sm mb-2">Équipe 2</h4>
              <div class="text-4xl font-bold text-white">
                {@cumulative_scores[1]}
              </div>
              <div class="text-white/60 text-xs mt-1">points</div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp last_trick_display(assigns) do
    # Get the last completed trick
    {_team, last_trick} = List.last(assigns.game.tricks_won)
    assigns = assign(assigns, :last_trick, last_trick)

    ~H"""
    <div class="relative w-full h-32">
      <%= for {{card, position}, _index} <- Enum.with_index(@last_trick.cards) do %>
        <% player_name = Map.get(@player_names, position, "Joueur #{position + 1}") %>
        <.last_trick_card
          card={card}
          position={position}
          my_position={@my_position}
          player_name={player_name}
        />
      <% end %>
    </div>
    """
  end

  defp last_trick_card(assigns) do
    # Position card in a row based on player position relative to viewer
    position_offset = rem(assigns.position - assigns.my_position + 4, 4)

    left =
      case position_offset do
        0 ->
          "12.5%"

        # Bottom (me)
        1 ->
          "37.5%"

        # Right
        2 ->
          "62.5%"

        # Top
        3 ->
          "87.5%"
          # Left
      end

    assigns = Map.merge(assigns, %{left: left, position_offset: position_offset})

    ~H"""
    <div
      class="absolute top-1/2 transform -translate-x-1/2 -translate-y-1/2 opacity-70"
      style={"left: #{@left};"}
    >
      <div class="flex flex-col items-center gap-1">
        <div class="text-xs font-semibold text-white bg-black/50 px-2 py-1 rounded whitespace-nowrap">
          {@player_name}
        </div>
        <div class={[
          "w-12 h-16 bg-white dark:bg-gray-100 rounded shadow-lg flex items-center justify-center",
          "border transition-colors text-xs",
          @card.suit in [:hearts, :diamonds] && "text-red-600 dark:text-red-500 border-red-200",
          @card.suit in [:spades, :clubs] && "text-gray-900 dark:text-gray-800 border-gray-200"
        ]}>
          <div class="text-center">
            <div class="text-lg font-bold">
              {rank_symbol(@card.rank)}
            </div>
            <div class="text-base">
              {suit_symbol(@card.suit)}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp chat_panel(assigns) do
    ~H"""
    <div class="bg-white/10 backdrop-blur-sm rounded-lg p-4 h-[600px] flex flex-col">
      <h3 class="text-white font-semibold mb-4">💬 Chat</h3>
      
    <!-- Messages Container -->
      <div
        id="chat-messages"
        class="flex-1 overflow-y-auto mb-4 space-y-2"
        phx-hook="ScrollToBottom"
      >
        <div id="chat-messages-stream" phx-update="stream">
          <%= for {dom_id, msg} <- @streams.chat_messages do %>
            <div
              id={dom_id}
              class={[
                "p-2 rounded-lg text-sm",
                msg.message_type == "system" && "bg-blue-500/20 text-blue-100 italic",
                msg.message_type == "user" && "bg-white/10"
              ]}
            >
              <%= if msg.message_type == "user" do %>
                <div class="flex items-baseline gap-2">
                  <span class="font-semibold text-white text-xs">
                    {msg.user.username}
                  </span>
                  <span class="text-white/40 text-xs">
                    {format_time(msg.inserted_at)}
                  </span>
                </div>
                <p class="text-white/90 mt-1">{msg.message}</p>
              <% else %>
                <p class="text-blue-100">{msg.message}</p>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
      
    <!-- Chat Input -->
      <form phx-submit="send_chat" class="flex gap-2" id="chat-form">
        <input
          type="text"
          name="message"
          id="chat-input"
          placeholder="Envoyer un message..."
          autocomplete="off"
          phx-hook="ChatInput"
          class="flex-1 px-3 py-2 bg-white/20 text-white placeholder-white/50 rounded-lg border border-white/30 focus:outline-none focus:ring-2 focus:ring-white/50"
        />
        <button
          type="submit"
          class="flex-shrink-0 px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition-colors"
        >
          Envoyer
        </button>
      </form>
    </div>
    """
  end

  defp card_display(assigns) do
    ~H"""
    <div class={[
      "w-16 h-24 bg-white dark:bg-gray-100 rounded-lg shadow-lg flex items-center justify-center",
      "border-2 transition-colors",
      @card.suit in [:hearts, :diamonds] && "text-red-600 dark:text-red-500 border-red-200",
      @card.suit in [:spades, :clubs] && "text-gray-900 dark:text-gray-800 border-gray-200"
    ]}>
      <div class="text-center">
        <div class="text-2xl font-bold">
          {rank_symbol(@card.rank)}
        </div>
        <div class="text-xl">
          {suit_symbol(@card.suit)}
        </div>
      </div>
    </div>
    """
  end

  defp trick_card(assigns) do
    # Position card in circle based on player position relative to viewer
    position_offset = rem(assigns.position - assigns.my_position + 4, 4)

    {top, left} =
      case position_offset do
        0 ->
          {"75%", "50%"}

        # Bottom (me)
        1 ->
          {"50%", "75%"}

        # Right
        2 ->
          {"25%", "50%"}

        # Top
        3 ->
          {"50%", "25%"}
          # Left
      end

    assigns = Map.merge(assigns, %{top: top, left: left, position_offset: position_offset})

    ~H"""
    <div
      class="absolute transform -translate-x-1/2 -translate-y-1/2"
      style={"top: #{@top}; left: #{@left};"}
    >
      <div class="flex flex-col items-center gap-1">
        <!-- Player name above card for top position, below for others -->
        <%= if @position_offset == 2 do %>
          <div class="text-xs font-semibold text-white bg-black/50 px-2 py-1 rounded whitespace-nowrap">
            {@player_name}
          </div>
        <% end %>
        <.card_display card={@card} />
        <%= if @position_offset != 2 do %>
          <div class="text-xs font-semibold text-white bg-black/50 px-2 py-1 rounded whitespace-nowrap">
            {@player_name}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp is_my_turn?(game, my_position) do
    current_pos =
      case game.status do
        :bidding when game.bidding != nil -> game.bidding.current_bidder
        _ -> game.current_player_position
      end

    current_pos == my_position
  end

  # Helper functions for card display
  defp rank_symbol(rank) do
    case rank do
      :seven -> "7"
      :eight -> "8"
      :nine -> "9"
      :ten -> "10"
      :jack -> "V"
      :queen -> "D"
      :king -> "R"
      :ace -> "A"
    end
  end

  defp suit_symbol(suit) do
    case suit do
      :hearts -> "♥"
      :diamonds -> "♦"
      :clubs -> "♣"
      :spades -> "♠"
    end
  end

  defp suit_name(suit) do
    case suit do
      :hearts -> "Cœur"
      :diamonds -> "Carreau"
      :clubs -> "Trèfle"
      :spades -> "Pique"
    end
  end

  defp format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M")
  end

  defp format_time(_), do: ""
end
