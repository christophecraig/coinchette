defmodule CoinchetteWeb.LobbyLive do
  use CoinchetteWeb, :live_view

  alias Coinchette.{Multiplayer, GameServerSupervisor}

  on_mount {CoinchetteWeb.Auth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to lobby updates (optional, for future real-time lobby list)
      Phoenix.PubSub.subscribe(Coinchette.PubSub, "lobby")

      # Subscribe to game invites for this user
      Phoenix.PubSub.subscribe(
        Coinchette.PubSub,
        "user:#{socket.assigns.current_user.id}:game_invites"
      )

      # Track user as online for friends system
      CoinchetteWeb.Presence.track(self(), "users:online", socket.assigns.current_user.id, %{
        username: socket.assigns.current_user.username
      })
    end

    socket =
      socket
      |> assign(:page_title, "Lobby")
      |> assign(:join_room_code, "")
      |> load_games()

    {:ok, socket}
  end

  def handle_event("create_game", _params, socket) do
    case Multiplayer.create_game(socket.assigns.current_user.id, variant: "belote") do
      {:ok, game} ->
        # Start the GameServer for this game
        {:ok, _pid} = GameServerSupervisor.start_game(game.id)

        {:noreply,
         socket
         |> put_flash(:info, "Game created! Room code: #{game.room_code}")
         |> push_navigate(to: ~p"/game/#{game.id}/lobby")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create game")}
    end
  end

  def handle_event("create_solo_game", _params, socket) do
    case Multiplayer.create_game(socket.assigns.current_user.id, variant: "belote") do
      {:ok, game} ->
        # Start the GameServer for this game
        {:ok, _pid} = GameServerSupervisor.start_game(game.id)

        # Immediately start the game (will auto-fill with bots)
        alias Coinchette.GameServer

        case GameServer.start_game(game.id) do
          {:ok, _started_game} ->
            {:noreply, push_navigate(socket, to: ~p"/game/#{game.id}/play")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to start game")}
        end

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create game")}
    end
  end

  def handle_event("validate_join", %{"room_code" => code}, socket) do
    {:noreply, assign(socket, :join_room_code, String.upcase(code))}
  end

  def handle_event("join_game", %{"room_code" => code}, socket) do
    room_code = String.upcase(String.trim(code))

    case Multiplayer.get_game_by_room_code(room_code) do
      nil ->
        {:noreply, put_flash(socket, :error, "Game not found with code: #{room_code}")}

      game ->
        if game.status == "finished" do
          {:noreply, put_flash(socket, :error, "This game has already finished")}
        else
          {:noreply, push_navigate(socket, to: ~p"/game/#{game.id}/lobby")}
        end
    end
  end

  def handle_event("view_game", %{"id" => game_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}/lobby")}
  end

  defp load_games(socket) do
    games = Multiplayer.list_user_games(socket.assigns.current_user.id)

    # Separate active and finished games
    {active_games, finished_games} =
      Enum.split_with(games, fn game -> game.status in ["waiting", "playing"] end)

    # Separate playing games (need rejoin) from waiting games
    {playing_games, waiting_games} =
      Enum.split_with(active_games, fn game -> game.status == "playing" end)

    socket
    |> assign(:playing_games, playing_games)
    |> assign(:active_games, active_games)
    |> assign(:finished_games, Enum.take(finished_games, 5))
  end

  def handle_info({:game_invite_received, %{from_username: username, game_id: game_id}}, socket) do
    {:noreply,
     push_event(socket, "toast", %{
       type: "info",
       message: "#{username} vous invite à rejoindre sa partie !",
       duration: 8000,
       action_label: "Rejoindre",
       action_url: "/game/#{game_id}/lobby"
     })}
  end

  def render(assigns) do
    ~H"""
    <div id="lobby-toast" phx-hook="Toast">
      <div class="mx-auto max-w-6xl px-2 sm:px-4 md:px-6 lg:px-8 pb-20 sm:pb-0">
        <!-- Hero Section -->
        <div class="text-center py-8 sm:py-12 mb-8">
          <div class="flex items-center justify-center gap-3 mb-4">
            <span class="text-5xl sm:text-6xl">🃏</span>
            <h1 class="text-4xl sm:text-5xl lg:text-6xl font-bold bg-gradient-to-r from-red-600 via-yellow-500 to-blue-600 bg-clip-text text-transparent">
              Coinchette
            </h1>
          </div>

          <p class="text-lg sm:text-xl text-base-content/80 mb-2">
            La belote et la coinche en ligne
          </p>

          <p class="text-sm sm:text-base text-base-content/60 max-w-2xl mx-auto">
            Jouez seul contre des bots intelligents ou créez une partie avec vos amis.
            Règles officielles FFB.
          </p>
          
    <!-- User greeting -->
          <div class="mt-6 flex items-center justify-center gap-2 text-base-content/70">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
              />
            </svg>
            <span class="font-medium">{@current_user.username}</span>
            <div class="hidden sm:flex items-center gap-2 ml-4">
              <.link navigate={~p"/friends"} class="btn btn-ghost btn-sm gap-1">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
                Amis
              </.link>
              <.volume_control id="lobby-volume-control" />
              <Layouts.theme_toggle />
            </div>
          </div>
        </div>
        
    <!-- Rejoin banner for playing games -->
        <%= if !Enum.empty?(@playing_games) do %>
          <div class="max-w-2xl mx-auto mb-8">
            <%= for game <- @playing_games do %>
              <div class="alert alert-warning shadow-lg mb-3 animate-pulse">
                <div class="flex items-center justify-between w-full gap-4">
                  <div class="flex items-center gap-3">
                    <span class="text-2xl">🎴</span>
                    <div>
                      <h3 class="font-bold">Partie en cours !</h3>
                      <p class="text-sm">
                        Code: <span class="font-mono font-bold">{game.room_code}</span>
                      </p>
                    </div>
                  </div>
                  <.link
                    navigate={~p"/game/#{game.id}/play"}
                    class="btn btn-sm btn-primary"
                  >
                    Reprendre la partie
                  </.link>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
        
    <!-- Actions rapides -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8 max-w-2xl mx-auto">
          <!-- Partie Solo -->
          <button
            phx-click="create_solo_game"
            class="card bg-gradient-to-br from-primary to-primary-focus hover:shadow-xl transition-all p-6 sm:p-8"
          >
            <div class="text-white text-center">
              <div class="text-4xl mb-3">🤖</div>
              <h3 class="text-lg sm:text-xl font-bold mb-2">Partie Solo</h3>
              <p class="text-sm opacity-90">
                Jouer contre 3 bots
              </p>
            </div>
          </button>
          <!-- Créer une partie -->
          <button
            phx-click="create_game"
            data-testid="create-game-button"
            class="card bg-gradient-to-br from-secondary to-secondary-focus hover:shadow-xl transition-all p-6 sm:p-8"
          >
            <div class="text-white text-center">
              <div class="text-4xl mb-3">👥</div>
              <h3 class="text-lg sm:text-xl font-bold mb-2">Créer une Partie</h3>
              <p class="text-sm opacity-90">
                Inviter des amis
              </p>
            </div>
          </button>
        </div>
        
    <!-- Rejoindre avec code (plus discret) -->
        <div class="max-w-md mx-auto mb-8">
          <div class="card bg-base-200 p-4 sm:p-6">
            <h3 class="text-base sm:text-lg font-semibold mb-3 text-center">
              Rejoindre une partie
            </h3>
            <.form for={%{}} phx-submit="join_game" phx-change="validate_join">
              <div class="flex gap-2">
                <input
                  type="text"
                  name="room_code"
                  value={@join_room_code}
                  placeholder="Code (ABC123)"
                  maxlength="6"
                  class="input input-bordered flex-1 uppercase font-mono text-center tracking-widest"
                  autocomplete="off"
                  data-testid="room-code-input"
                />
                <.button type="submit" class="btn-primary" data-testid="join-game-button">
                  Rejoindre
                </.button>
              </div>
            </.form>
          </div>
        </div>
        
    <!-- Parties actives -->
        <%= if !Enum.empty?(@active_games) do %>
          <div>
            <h2 class="text-xl sm:text-2xl font-bold mb-4 flex items-center gap-2">
              <span>🎮</span>
              <span>Vos parties en cours</span>
            </h2>

            <div
              class="grid grid-cols-1 lg:grid-cols-2 gap-3 sm:gap-4"
              data-testid="active-games-list"
            >
              <%= for game <- @active_games do %>
                <div
                  class="card bg-base-200 hover:bg-base-300 transition-all cursor-pointer p-4 sm:p-6"
                  phx-click="view_game"
                  phx-value-id={game.id}
                  data-testid={"game-card-#{game.id}"}
                >
                  <div class="flex items-center justify-between">
                    <div class="flex-1">
                      <div class="flex items-center gap-3 mb-2">
                        <span class="badge badge-lg font-mono">{game.room_code}</span>
                        <span class={[
                          "badge",
                          game.status == "waiting" && "badge-warning",
                          game.status == "playing" && "badge-success"
                        ]}>
                          {status_text(game.status)}
                        </span>
                      </div>
                      <div class="text-sm text-base-content/60">
                        {length(game.game_players)}/4 joueurs • {format_relative_time(
                          game.inserted_at
                        )}
                      </div>
                    </div>
                    <svg
                      class="w-6 h-6 text-base-content/40"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M9 5l7 7-7 7"
                      />
                    </svg>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
        
    <!-- Parties terminées -->
        <%= if !Enum.empty?(@finished_games) do %>
          <div>
            <h2 class="text-lg sm:text-xl font-semibold mb-4 text-base-content/70">
              Dernières parties terminées
            </h2>
            <div class="space-y-2">
              <%= for game <- @finished_games do %>
                <div class="card bg-base-200/50 p-3 sm:p-4 flex flex-row items-center justify-between">
                  <div>
                    <span class="font-mono font-semibold">{game.room_code}</span>
                    <span class="text-sm text-base-content/60 ml-3">
                      {format_relative_time(game.finished_at || game.updated_at)}
                    </span>
                  </div>
                  <.link navigate={~p"/game/#{game.id}/history"} class="btn btn-ghost btn-sm">
                    Voir
                  </.link>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
      
    <!-- Bottom Navigation (visible sur mobile uniquement) -->
      <div class="block sm:hidden">
        <CoinchetteWeb.BottomNav.bottom_nav current_path="/lobby" />
      </div>
    </div>
    """
  end

  defp format_relative_time(nil), do: "récemment"

  defp format_relative_time(datetime) do
    now = NaiveDateTime.utc_now()
    diff = NaiveDateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "à l'instant"
      diff < 3600 -> "il y a #{div(diff, 60)} min"
      diff < 86400 -> "il y a #{div(diff, 3600)}h"
      diff < 604_800 -> "il y a #{div(diff, 86400)}j"
      true -> "il y a plus d'une semaine"
    end
  end

  defp status_text("waiting"), do: "En attente"
  defp status_text("playing"), do: "En cours"
  defp status_text(_), do: "Terminée"
end
