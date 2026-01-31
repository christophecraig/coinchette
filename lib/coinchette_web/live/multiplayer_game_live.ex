defmodule CoinchetteWeb.MultiplayerGameLive do
  use CoinchetteWeb, :live_view

  alias Coinchette.{Multiplayer, GameServer}
  alias Coinchette.Games.{Game, Card}

  on_mount {CoinchetteWeb.Auth, :ensure_authenticated}

  def mount(%{"id" => game_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to game updates
      Phoenix.PubSub.subscribe(Coinchette.PubSub, "game:#{game_id}")
    end

    # Get game state from GameServer
    state = GameServer.get_state(game_id)
    game = state.game

    # Find user's position
    my_position = find_user_position(state.player_map, socket.assigns.current_user.id)

    # Load chat messages and set up stream
    chat_messages = Multiplayer.list_chat_messages(game_id)

    socket =
      socket
      |> assign(:page_title, "Playing Game")
      |> assign(:game, game)
      |> assign(:game_id, game_id)
      |> assign(:my_position, my_position)
      |> assign(:player_map, state.player_map)
      |> assign(:bot_positions, state.bot_positions)
      |> assign(:selected_card, nil)
      |> assign(:message, get_game_message(game, my_position))
      |> assign(:belote_announcement, nil)
      |> stream(:chat_messages, chat_messages)
      |> load_player_names(game_id)

    {:ok, socket}
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

      case GameServer.make_bid(socket.assigns.game_id, socket.assigns.current_user.id, {:choose, suit}) do
        {:ok, _game} ->
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

    {:noreply, socket}
  end

  ## PubSub Event Handlers

  def handle_info({:game_updated, game}, socket) do
    # Detect belote announcement
    announcement = detect_belote_announcement(socket.assigns.game, game)

    {:noreply,
     socket
     |> assign(:game, game)
     |> assign(:message, get_game_message(game, socket.assigns.my_position))
     |> assign(:belote_announcement, announcement)}
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

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  ## Helper Functions

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
            "Bot (#{p.bot_difficulty})"
          else
            p.user.username
          end

        {p.position, name}
      end)
      |> Enum.into(%{})

    assign(socket, :player_names, player_names)
  end

  defp get_player_name(socket, position) do
    Map.get(socket.assigns.player_names, position, "Joueur #{position + 1}")
  end

  defp detect_belote_announcement(old_game, new_game) do
    cond do
      # Belote annoncée (premier Roi ou Dame d'atout joué)
      old_game.belote_announced == nil && new_game.belote_announced != nil ->
        {pos, _card_type} = new_game.belote_announced
        player = Enum.at(new_game.players, pos)
        {:belote, player.team}

      # Rebelote (deuxième carte de la paire jouée)
      old_game.belote_rebelote == {new_game.belote_rebelote |> elem(0), false} &&
          new_game.belote_rebelote != nil && elem(new_game.belote_rebelote, 1) == true ->
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
        "Tous ont passé ! Redistribution nécessaire"

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
    <div class="min-h-screen bg-gradient-to-br from-green-800 to-green-600 p-4 sm:p-8">
      <div class="max-w-6xl mx-auto">
        <!-- Header -->
        <div class="flex items-center justify-between mb-6">
          <div class="text-white">
            <h1 class="text-2xl sm:text-4xl font-bold">🃏 Coinchette</h1>
            <p class="text-green-100 text-sm sm:text-lg mt-1">{@message}</p>
          </div>
          <button phx-click="leave_game" class="btn btn-ghost btn-sm text-white">
            Quitter
          </button>
        </div>

        <!-- Belote/Rebelote Notification -->
        <%= if @belote_announcement do %>
          <.belote_notification announcement={@belote_announcement} player_names={@player_names} />
        <% end %>

        <!-- Announcements Notification -->
        <%= if @game.announcements_result && @game.announcements_result.total_points > 0 && length(@game.tricks_won) <= 1 do %>
          <.announcements_notification result={@game.announcements_result} />
        <% end %>

        <%= if @game.status == :bidding do %>
          <!-- Bidding Interface -->
          <.bidding_interface
            game={@game}
            is_my_turn={is_my_turn?(@game, @my_position)}
            player_names={@player_names}
          />
        <% else %>
          <!-- Game Board with Chat -->
          <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
            <div class="lg:col-span-3">
              <.game_board
                game={@game}
                my_position={@my_position}
                player_names={@player_names}
                is_my_turn={is_my_turn?(@game, @my_position)}
              />
            </div>

            <!-- Chat Sidebar -->
            <div class="lg:col-span-1">
              <.chat_panel streams={@streams} />
            </div>
          </div>
        <% end %>

        <!-- Score Panel -->
        <.score_panel game={@game} my_position={@my_position} player_names={@player_names} />
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
    ~H"""
    <div class="alert alert-info shadow-lg mb-4">
      <div>
        <h3 class="font-bold text-lg">
          Annonces : +<%= @result.total_points %> points pour l'Équipe <%= @result.team + 1 %>
        </h3>
        <div class="text-sm mt-1 space-y-1">
          <%= for {type, points} <- @result.announcements do %>
            <div>
              <%= case type do %>
                <% :tierce -> %>
                  Tierce : +<%= points %> points
                <% :cinquante -> %>
                  Cinquante : +<%= points %> points
                <% :cent -> %>
                  Cent : +<%= points %> points
                <% :carre -> %>
                  Carré : +<%= points %> points
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
          Phase d'enchères - <%= if @game.bidding.round == 1, do: "Premier", else: "Second" %> tour
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
                  <%= suit_symbol(suit) %> <%= suit_name(suit) %>
                </button>
              <% end %>
              <button phx-click="bid_pass" class="btn btn-error">
                Passer
              </button>
            <% end %>
          <% else %>
            <div class="text-white/60">
              En attente de <%= Map.get(@player_names, @game.bidding.current_bidder, "Joueur") %>...
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
          <%= if @game.current_trick do %>
            <div class="relative aspect-square max-w-md mx-auto mb-6">
              <div class="absolute inset-0 bg-green-700/50 rounded-full border-4 border-white/20"></div>
              <%= for {card, pos} <- @game.current_trick.cards do %>
                <.trick_card card={card} position={pos} my_position={@my_position} />
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
              <div class={[
                "p-3 rounded-lg",
                is_current && "bg-yellow-500/30 ring-2 ring-yellow-400",
                !is_current && "bg-white/5",
                is_me && "ring-2 ring-blue-400"
              ]}>
                <div class="flex items-center justify-between">
                  <div>
                    <div class="text-white font-medium">
                      <%= Map.get(@player_names, player.position, "Joueur #{player.position + 1}") %>
                      <%= if is_me do %>
                        <span class="badge badge-sm badge-primary ml-2">Vous</span>
                      <% end %>
                    </div>
                    <div class="text-white/60 text-sm">
                      Équipe <%= player.team + 1 %> • Position <%= player.position + 1 %>
                    </div>
                  </div>
                  <div class="text-white/40 text-sm">
                    <%= length(player.hand) %> cartes
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

  defp score_panel(assigns) do
    ~H"""
    <div class="mt-6 bg-white/10 backdrop-blur-sm rounded-lg p-6">
      <div class="grid grid-cols-2 gap-6 text-center">
        <div>
          <h3 class="text-white/80 text-sm mb-2">Équipe 1</h3>
          <div class="text-3xl font-bold text-white">
            <%= @game.scores[0] %>
          </div>
          <div class="text-white/60 text-sm mt-1">
            <%= Enum.count(@game.tricks_won, fn {team, _} -> team == 0 end) %> plis
          </div>
        </div>
        <div>
          <h3 class="text-white/80 text-sm mb-2">Équipe 2</h3>
          <div class="text-3xl font-bold text-white">
            <%= @game.scores[1] %>
          </div>
          <div class="text-white/60 text-sm mt-1">
            <%= Enum.count(@game.tricks_won, fn {team, _} -> team == 1 end) %> plis
          </div>
        </div>
      </div>

      <%= if @game.trump_suit do %>
        <div class="mt-4 text-center">
          <span class="text-white/80 text-sm">Atout: </span>
          <span class="text-xl font-semibold text-white">
            <%= suit_symbol(@game.trump_suit) %> <%= suit_name(@game.trump_suit) %>
          </span>
        </div>
      <% end %>
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
            <div id={dom_id} class={[
              "p-2 rounded-lg text-sm",
              msg.message_type == "system" && "bg-blue-500/20 text-blue-100 italic",
              msg.message_type == "user" && "bg-white/10"
            ]}>
              <%= if msg.message_type == "user" do %>
                <div class="flex items-baseline gap-2">
                  <span class="font-semibold text-white text-xs">
                    <%= msg.user.username %>
                  </span>
                  <span class="text-white/40 text-xs">
                    <%= format_time(msg.inserted_at) %>
                  </span>
                </div>
                <p class="text-white/90 mt-1"><%= msg.message %></p>
              <% else %>
                <p class="text-blue-100"><%= msg.message %></p>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Chat Input -->
      <form phx-submit="send_chat" class="flex gap-2">
        <input
          type="text"
          name="message"
          placeholder="Envoyer un message..."
          autocomplete="off"
          class="flex-1 px-3 py-2 bg-white/20 text-white placeholder-white/50 rounded-lg border border-white/30 focus:outline-none focus:ring-2 focus:ring-white/50"
        />
        <button
          type="submit"
          class="px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition-colors"
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
      "w-16 h-24 bg-white rounded-lg shadow-lg flex items-center justify-center",
      "border-2",
      @card.suit in [:hearts, :diamonds] && "text-red-600 border-red-200",
      @card.suit in [:spades, :clubs] && "text-gray-800 border-gray-200"
    ]}>
      <div class="text-center">
        <div class="text-2xl font-bold">
          <%= rank_symbol(@card.rank) %>
        </div>
        <div class="text-xl">
          <%= suit_symbol(@card.suit) %>
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
        0 -> {"75%", "50%"}
        # Bottom (me)
        1 -> {"50%", "75%"}
        # Right
        2 -> {"25%", "50%"}
        # Top
        3 -> {"50%", "25%"}
        # Left
      end

    assigns = Map.merge(assigns, %{top: top, left: left})

    ~H"""
    <div
      class="absolute transform -translate-x-1/2 -translate-y-1/2"
      style={"top: #{@top}; left: #{@left};"}
    >
      <.card_display card={@card} />
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
