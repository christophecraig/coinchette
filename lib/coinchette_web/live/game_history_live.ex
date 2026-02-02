defmodule CoinchetteWeb.GameHistoryLive do
  use CoinchetteWeb, :live_view

  alias Coinchette.Multiplayer

  on_mount {CoinchetteWeb.Auth, :ensure_authenticated}

  def mount(%{"id" => game_id}, _session, socket) do
    # Load the game with all related data
    game = Multiplayer.get_game!(game_id)

    # Check if game is finished
    if game.status != "finished" do
      {:ok,
       socket
       |> put_flash(:error, "This game is not finished yet")
       |> push_navigate(to: ~p"/lobby")}
    else
      # Load game events and players
      events = Multiplayer.list_game_events(game_id)
      players = Multiplayer.list_game_players(game_id)

      # Decode game state if available
      game_state = Multiplayer.Game.decode_game_state(game.state)

      # Build player names map
      player_names = build_player_names(players)

      # Determine if current user was in this game
      user_position = find_user_position(players, socket.assigns.current_user.id)

      socket =
        socket
        |> assign(:page_title, "Game History")
        |> assign(:game, game)
        |> assign(:game_state, game_state)
        |> assign(:events, events)
        |> assign(:players, players)
        |> assign(:player_names, player_names)
        |> assign(:user_position, user_position)

      {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 p-4 sm:p-8">
      <div class="max-w-6xl mx-auto">
        <!-- Header -->
        <div class="mb-6">
          <.link navigate="/profile" class="btn btn-ghost btn-sm mb-4">
            ← Retour au profil
          </.link>
          <h1 class="text-3xl sm:text-4xl font-bold text-base-content">
            Historique de partie
          </h1>
          <p class="text-base-content/60 mt-2">
            Partie terminée le <%= format_datetime(@game.finished_at) %>
          </p>
        </div>

        <!-- Game Summary -->
        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body">
            <h2 class="card-title">📊 Résumé</h2>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
              <!-- Winner -->
              <div class="stat bg-base-200 rounded-lg">
                <div class="stat-title">Vainqueur</div>
                <div class="stat-value text-2xl">
                  Équipe <%= (@game.winner_team || 0) + 1 %>
                </div>
                <div class="stat-desc">
                  <%= if @game.winner_team do %>
                    <%= get_team_players(@players, @game.winner_team, @player_names)
                    |> Enum.join(" & ") %>
                  <% end %>
                </div>
              </div>

              <!-- Scores -->
              <div class="stat bg-base-200 rounded-lg">
                <div class="stat-title">Score final</div>
                <div class="stat-value text-2xl">
                  <%= if @game.scores do %>
                    <%= Map.get(@game.scores, "0", 0) %> - <%= Map.get(@game.scores, "1", 0) %>
                  <% else %>
                    N/A
                  <% end %>
                </div>
                <div class="stat-desc">
                  <%= if @game.scores do %>
                    Différence: <%= abs(
                      Map.get(@game.scores, "0", 0) - Map.get(@game.scores, "1", 0)
                    ) %> points
                  <% end %>
                </div>
              </div>

              <!-- Duration -->
              <div class="stat bg-base-200 rounded-lg">
                <div class="stat-title">Durée</div>
                <div class="stat-value text-2xl">
                  <%= calculate_duration(@game.started_at, @game.finished_at) %>
                </div>
                <div class="stat-desc">
                  <%= Enum.count(@events) %> événements
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Players -->
        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body">
            <h2 class="card-title">👥 Joueurs</h2>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
              <%= for team <- [0, 1] do %>
                <div class={[
                  "p-4 rounded-lg",
                  @game.winner_team == team && "bg-success/20 ring-2 ring-success",
                  @game.winner_team != team && "bg-base-200"
                ]}>
                  <h3 class="font-semibold mb-3 flex items-center gap-2">
                    Équipe <%= team + 1 %>
                    <%= if @game.winner_team == team do %>
                      <span class="badge badge-success">Vainqueur</span>
                    <% end %>
                  </h3>

                  <div class="space-y-2">
                    <%= for player <- get_team_player_objects(@players, team) do %>
                      <div class="flex items-center gap-3">
                        <div class="avatar placeholder">
                          <div class="bg-neutral text-neutral-content rounded-full w-10">
                            <span class="text-sm">
                              <%= if player.is_bot do %>
                                🤖
                              <% else %>
                                <%= String.first(player.user.username) |> String.upcase() %>
                              <% end %>
                            </span>
                          </div>
                        </div>
                        <div>
                          <div class="font-medium">
                            <%= Map.get(@player_names, player.position) %>
                            <%= if player.position == @user_position do %>
                              <span class="badge badge-sm badge-primary ml-2">Vous</span>
                            <% end %>
                          </div>
                          <div class="text-sm text-base-content/60">
                            Position <%= player.position + 1 %>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>

                  <%= if @game.scores do %>
                    <div class="mt-3 pt-3 border-t border-base-300">
                      <div class="text-2xl font-bold">
                        <%= Map.get(@game.scores, Integer.to_string(team), 0) %> points
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Game Details -->
        <%= if @game_state do %>
          <.game_details_panel game_state={@game_state} player_names={@player_names} />
        <% end %>

        <!-- Events Timeline -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">📜 Chronologie des événements</h2>

            <div class="mt-4">
              <%= if Enum.empty?(@events) do %>
                <p class="text-base-content/60">Aucun événement enregistré</p>
              <% else %>
                <div class="space-y-2">
                  <%= for event <- @events do %>
                    <.event_item event={event} player_names={@player_names} />
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp game_details_panel(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl mb-6">
      <div class="card-body">
        <h2 class="card-title">🎮 Détails de la partie</h2>

        <div class="mt-4 space-y-4">
          <!-- Trump Suit -->
          <%= if @game_state.trump_suit do %>
            <div>
              <h3 class="font-semibold mb-2">Atout</h3>
              <div class="text-2xl">
                <%= suit_symbol(@game_state.trump_suit) %> <%= suit_name(@game_state.trump_suit) %>
              </div>
            </div>
          <% end %>

          <!-- Tricks Won -->
          <%= if @game_state.tricks_won && length(@game_state.tricks_won) > 0 do %>
            <div>
              <h3 class="font-semibold mb-2">Plis remportés</h3>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <span class="text-base-content/60">Équipe 1:</span>
                  <span class="font-bold ml-2">
                    <%= Enum.count(@game_state.tricks_won, fn {team, _} -> team == 0 end) %> plis
                  </span>
                </div>
                <div>
                  <span class="text-base-content/60">Équipe 2:</span>
                  <span class="font-bold ml-2">
                    <%= Enum.count(@game_state.tricks_won, fn {team, _} -> team == 1 end) %> plis
                  </span>
                </div>
              </div>
            </div>

            <!-- Show all tricks -->
            <div>
              <h3 class="font-semibold mb-3">Historique des plis</h3>
              <div class="space-y-4">
                <%= for {{team, trick}, index} <- Enum.with_index(@game_state.tricks_won) do %>
                  <div class="bg-base-200 rounded-lg p-4">
                    <div class="flex items-center justify-between mb-3">
                      <h4 class="font-medium">Pli <%= index + 1 %></h4>
                      <span class="badge badge-primary">Remporté par l'Équipe <%= team + 1 %></span>
                    </div>
                    <div class="flex flex-wrap gap-2">
                      <%= for {{card, position}, _} <- Enum.with_index(trick.cards) do %>
                        <div class="text-center">
                          <div class={[
                            "w-16 h-20 bg-white dark:bg-gray-100 rounded shadow flex items-center justify-center border-2",
                            card.suit in [:hearts, :diamonds] && "text-red-600 border-red-200",
                            card.suit in [:spades, :clubs] && "text-gray-900 border-gray-200"
                          ]}>
                            <div class="text-center">
                              <div class="text-lg font-bold"><%= rank_symbol(card.rank) %></div>
                              <div class="text-base"><%= suit_symbol(card.suit) %></div>
                            </div>
                          </div>
                          <div class="text-xs mt-1 text-base-content/60">
                            <%= Map.get(@player_names, position, "P#{position + 1}") %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Announcements -->
          <%= if @game_state.announcements_result do %>
            <div>
              <h3 class="font-semibold mb-2">Annonces</h3>
              <div class="bg-base-200 rounded-lg p-3">
                <div class="text-sm">
                  Points d'annonces: <span class="font-bold">
                    <%= @game_state.announcements_result.total_points %>
                  </span>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Belote/Rebelote -->
          <%= if @game_state.belote_rebelote do %>
            <div>
              <h3 class="font-semibold mb-2">Belote/Rebelote</h3>
              <div class="bg-base-200 rounded-lg p-3">
                <% {team, _} = @game_state.belote_rebelote %>
                <div class="flex items-center gap-2">
                  <span class="text-2xl">👑</span>
                  <span>Annoncée par l'Équipe <%= team + 1 %> (+20 points)</span>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp event_item(assigns) do
    ~H"""
    <div class="flex items-start gap-3 p-3 bg-base-200 rounded-lg">
      <div class="text-2xl flex-shrink-0">
        <%= event_icon(@event.event_type) %>
      </div>
      <div class="flex-1">
        <div class="font-medium">
          <%= format_event_description(@event, @player_names) %>
        </div>
        <div class="text-xs text-base-content/60">
          <%= format_datetime(@event.inserted_at) %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp build_player_names(players) do
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
  end

  defp find_user_position(players, user_id) do
    players
    |> Enum.find(fn p -> p.user_id == user_id end)
    |> case do
      nil -> nil
      player -> player.position
    end
  end

  defp get_team_players(players, team, player_names) do
    players
    |> Enum.filter(fn p -> rem(p.position, 2) == team end)
    |> Enum.map(fn p -> Map.get(player_names, p.position) end)
  end

  defp get_team_player_objects(players, team) do
    players
    |> Enum.filter(fn p -> rem(p.position, 2) == team end)
    |> Enum.sort_by(& &1.position)
  end

  defp calculate_duration(nil, _), do: "N/A"
  defp calculate_duration(_, nil), do: "N/A"

  defp calculate_duration(started_at, finished_at) do
    diff = NaiveDateTime.diff(finished_at, started_at, :second)
    minutes = div(diff, 60)
    seconds = rem(diff, 60)

    if minutes > 0 do
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(datetime) do
    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> Calendar.strftime("%d/%m/%Y à %H:%M")
  end

  defp event_icon(event_type) do
    case event_type do
      "game_created" -> "🎮"
      "player_joined" -> "👋"
      "player_left" -> "👋"
      "game_started" -> "🚀"
      "bid_made" -> "💬"
      "card_played" -> "🃏"
      "game_finished" -> "🏆"
      _ -> "📌"
    end
  end

  defp format_event_description(event, player_names) do
    case event.event_type do
      "game_created" ->
        "Partie créée"

      "player_joined" ->
        player_name = Map.get(player_names, event.data["position"])
        "#{player_name || "Joueur"} a rejoint la partie"

      "player_left" ->
        "Un joueur a quitté la partie"

      "game_started" ->
        "La partie a commencé"

      "bid_made" ->
        "Enchère effectuée"

      "card_played" ->
        "Carte jouée"

      "game_finished" ->
        "Partie terminée"

      _ ->
        event.event_type
    end
  end

  defp suit_symbol(suit) do
    case suit do
      :hearts -> "♥"
      :diamonds -> "♦"
      :clubs -> "♣"
      :spades -> "♠"
      _ -> ""
    end
  end

  defp suit_name(suit) do
    case suit do
      :hearts -> "Cœur"
      :diamonds -> "Carreau"
      :clubs -> "Trèfle"
      :spades -> "Pique"
      _ -> ""
    end
  end

  defp rank_symbol(rank) do
    case rank do
      :ace -> "A"
      :seven -> "7"
      :eight -> "8"
      :nine -> "9"
      :ten -> "10"
      :jack -> "V"
      :queen -> "D"
      :king -> "R"
      _ -> ""
    end
  end
end
