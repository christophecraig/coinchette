defmodule CoinchetteWeb.LobbyLive do
  use CoinchetteWeb, :live_view

  alias Coinchette.{Multiplayer, GameServerSupervisor}

  on_mount {CoinchetteWeb.Auth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to lobby updates (optional, for future real-time lobby list)
      Phoenix.PubSub.subscribe(Coinchette.PubSub, "lobby")
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

    socket
    |> assign(:active_games, active_games)
    |> assign(:finished_games, Enum.take(finished_games, 5))
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
      <.header>
        Game Lobby
        <:subtitle>Welcome, <%= @current_user.username %>!</:subtitle>
        <:actions>
          <.button phx-click="create_game" data-testid="create-game-button">
            <svg class="w-5 h-5 mr-2 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 4v16m8-8H4"
              />
            </svg>
            Create New Game
          </.button>
        </:actions>
      </.header>

      <div class="mt-8 grid grid-cols-1 gap-8 lg:grid-cols-3">
        <!-- Left column: Join Game -->
        <div class="lg:col-span-1">
          <div class="bg-base-200 rounded-box p-6">
            <h2 class="text-lg font-semibold mb-4">Join Game</h2>
            <.form for={%{}} phx-submit="join_game" phx-change="validate_join">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Room Code</span>
                </label>
                <input
                  type="text"
                  name="room_code"
                  value={@join_room_code}
                  placeholder="ABC123"
                  maxlength="6"
                  class="input input-bordered w-full uppercase font-mono text-center text-lg tracking-widest"
                  autocomplete="off"
                  data-testid="room-code-input"
                />
                <label class="label">
                  <span class="label-text-alt">Enter 6-character room code</span>
                </label>
              </div>
              <.button type="submit" class="w-full mt-2" data-testid="join-game-button">
                Join Game
              </.button>
            </.form>

            <div class="divider">OR</div>

            <.link navigate="/game" class="btn btn-outline w-full">
              Play Solo Game
            </.link>
          </div>
        </div>

        <!-- Right column: Active Games -->
        <div class="lg:col-span-2">
          <h2 class="text-lg font-semibold mb-4">Your Active Games</h2>

          <%= if Enum.empty?(@active_games) do %>
            <div class="bg-base-200 rounded-box p-8 text-center">
              <p class="text-base-content/60">No active games</p>
              <p class="text-sm text-base-content/40 mt-2">
                Create a new game or join one with a room code
              </p>
            </div>
          <% else %>
            <div class="space-y-4" data-testid="active-games-list">
              <%= for game <- @active_games do %>
                <div class="bg-base-200 rounded-box p-4 hover:bg-base-300 transition cursor-pointer" phx-click="view_game" phx-value-id={game.id} data-testid={"game-card-#{game.id}"}>
                  <div class="flex items-center justify-between">
                    <div class="flex-1">
                      <div class="flex items-center gap-3">
                        <span class="badge badge-lg font-mono">
                          <%= game.room_code %>
                        </span>
                        <span class={[
                          "badge",
                          game.status == "waiting" && "badge-warning",
                          game.status == "playing" && "badge-success"
                        ]}>
                          <%= game.status %>
                        </span>
                      </div>
                      <div class="mt-2 text-sm text-base-content/60">
                        <span>
                          <%= length(game.game_players) %>/4 players
                        </span>
                        <span class="mx-2">•</span>
                        <span>
                          Created <%= format_relative_time(game.inserted_at) %>
                        </span>
                      </div>
                    </div>
                    <svg class="w-5 h-5 text-base-content/40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                    </svg>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>

          <%= if !Enum.empty?(@finished_games) do %>
            <div class="mt-8">
              <h2 class="text-lg font-semibold mb-4">Recent Finished Games</h2>
              <div class="space-y-2">
                <%= for game <- @finished_games do %>
                  <div class="bg-base-200/50 rounded-box p-3 text-sm">
                    <div class="flex items-center justify-between">
                      <div>
                        <span class="font-mono"><%= game.room_code %></span>
                        <span class="mx-2 text-base-content/40">•</span>
                        <span class="text-base-content/60">
                          Finished <%= format_relative_time(game.finished_at || game.updated_at) %>
                        </span>
                      </div>
                      <.link navigate={~p"/game/#{game.id}/history"} class="text-brand hover:underline text-xs">
                        View
                      </.link>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_relative_time(nil), do: "recently"

  defp format_relative_time(datetime) do
    now = NaiveDateTime.utc_now()
    diff = NaiveDateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604800 -> "#{div(diff, 86400)} days ago"
      true -> "over a week ago"
    end
  end
end
