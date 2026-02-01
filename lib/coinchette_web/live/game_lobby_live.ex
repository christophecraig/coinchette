defmodule CoinchetteWeb.GameLobbyLive do
  use CoinchetteWeb, :live_view

  alias Coinchette.{Multiplayer, GameServer, GameServerSupervisor}
  alias CoinchetteWeb.Presence

  on_mount {CoinchetteWeb.Auth, :ensure_authenticated}

  def mount(%{"id" => game_id}, _session, socket) do
    game = Multiplayer.get_game!(game_id)

    # Check if user is already a player or is the creator
    is_player = is_user_in_game?(game, socket.assigns.current_user.id)
    is_creator = game.creator_id == socket.assigns.current_user.id

    socket =
      if is_player or is_creator do
        if connected?(socket) do
          # Subscribe to game events
          Phoenix.PubSub.subscribe(Coinchette.PubSub, "game:#{game_id}")

          # Track user presence in lobby
          {:ok, _} = Presence.track(self(), "game:#{game_id}", socket.assigns.current_user.id, %{
            username: socket.assigns.current_user.username,
            joined_at: System.system_time(:second)
          })

          # Ensure GameServer is running
          case GameServerSupervisor.start_game(game_id) do
            {:ok, _pid} -> :ok
            {:error, {:already_started, _pid}} -> :ok
          end
        end

        socket
        |> assign(:page_title, "Game Lobby - #{game.room_code}")
        |> assign(:game, game)
        |> assign(:game_id, game_id)
        |> assign(:is_creator, is_creator)
        |> assign(:present_users, get_present_users(game_id))
        |> load_players()
      else
        # User is not in the game, try to join
        socket
        |> assign(:game, game)
        |> assign(:game_id, game_id)
        |> assign(:is_creator, false)
        |> assign(:joining, true)
      end

    {:ok, socket}
  end

  def handle_event("join_game", _params, socket) do
    game_id = socket.assigns.game_id
    user_id = socket.assigns.current_user.id

    # Find first available position
    case find_available_position(socket.assigns.game) do
      nil ->
        {:noreply, put_flash(socket, :error, "Game is full")}

      position ->
        case GameServer.add_player(game_id, user_id, position) do
          :ok ->
            # Reload game state
            game = Multiplayer.get_game!(game_id)

            {:noreply,
             socket
             |> assign(:game, game)
             |> assign(:joining, false)
             |> load_players()
             |> put_flash(:info, "Joined game!")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to join game")}
        end
    end
  end

  def handle_event("delete_game", _params, socket) do
    if socket.assigns.is_creator and socket.assigns.game.status == "waiting" do
      case GameServer.delete_game(socket.assigns.game_id, socket.assigns.current_user.id) do
        :ok ->
          {:noreply, push_navigate(socket, to: ~p"/lobby")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to delete game")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only the host can delete a waiting game")}
    end
  end

  def handle_event("remove_player", %{"user-id" => user_id}, socket) do
    if socket.assigns.is_creator or user_id == socket.assigns.current_user.id do
      case GameServer.remove_player(socket.assigns.game_id, user_id) do
        :ok ->
          if user_id == socket.assigns.current_user.id do
            {:noreply, push_navigate(socket, to: ~p"/lobby")}
          else
            {:noreply, socket}
          end

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to remove player")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only the host can remove players")}
    end
  end

  def handle_event("leave_game", _params, socket) do
    user_id = socket.assigns.current_user.id

    case GameServer.remove_player(socket.assigns.game_id, user_id) do
      :ok ->
        {:noreply, push_navigate(socket, to: ~p"/lobby")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to leave game")}
    end
  end

  def handle_event("start_game", _params, socket) do
    if socket.assigns.is_creator do
      case GameServer.start_game(socket.assigns.game_id) do
        {:ok, _game} ->
          {:noreply, push_navigate(socket, to: ~p"/game/#{socket.assigns.game_id}/play")}

        {:error, :not_enough_players} ->
          {:noreply, put_flash(socket, :error, "Need at least 2 players to start")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to start game")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only the host can start the game")}
    end
  end

  # PubSub event handlers
  def handle_info({:player_joined, _data}, socket) do
    {:noreply, reload_game_state(socket)}
  end

  def handle_info({:player_left, _data}, socket) do
    {:noreply, reload_game_state(socket)}
  end

  def handle_info({:game_started, _game}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/game/#{socket.assigns.game_id}/play")}
  end

  def handle_info({:game_deleted, _data}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Game has been deleted")
     |> push_navigate(to: ~p"/lobby")}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    # Update the list of present users when someone joins/leaves
    present_users = get_present_users(socket.assigns.game_id)
    {:noreply, assign(socket, :present_users, present_users)}
  end

  defp reload_game_state(socket) do
    game = Multiplayer.get_game!(socket.assigns.game_id)

    socket
    |> assign(:game, game)
    |> assign(:present_users, get_present_users(socket.assigns.game_id))
    |> load_players()
  end

  defp get_present_users(game_id) do
    Presence.list("game:#{game_id}")
    |> Map.keys()
    |> MapSet.new()
  end

  defp load_players(socket) do
    players = Multiplayer.list_game_players(socket.assigns.game_id)
    assign(socket, :players, players)
  end

  defp is_user_in_game?(game, user_id) do
    Enum.any?(game.game_players, fn player -> player.user_id == user_id end)
  end

  defp find_available_position(game) do
    occupied_positions = Enum.map(game.game_players, & &1.position) |> MapSet.new()

    Enum.find(0..3, fn pos -> !MapSet.member?(occupied_positions, pos) end)
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
      <%= if assigns[:joining] do %>
        <!-- Joining view for new players -->
        <div class="text-center py-12">
          <.header>
            Join Game <%= @game.room_code %>
          </.header>

          <div class="mt-8 bg-base-200 rounded-box p-8">
            <p class="text-lg mb-4">
              <%= length(@game.game_players) %>/4 players in game
            </p>
            <.button phx-click="join_game" class="btn-lg">
              Join Game
            </.button>
            <div class="mt-4">
              <.link navigate="/lobby" class="text-sm text-base-content/60 hover:underline">
                Back to Lobby
              </.link>
            </div>
          </div>
        </div>
      <% else %>
        <!-- Game lobby view for players -->
        <.header>
          Game Lobby
          <:subtitle>
            <div class="flex items-center gap-3">
              <span>Room Code:</span>
              <span class="badge badge-lg font-mono text-lg px-4">
                <%= @game.room_code %>
              </span>
              <button
                class="btn btn-xs btn-ghost"
                onclick={"navigator.clipboard.writeText('#{@game.room_code}')"}
                title="Copy room code"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                  />
                </svg>
              </button>
            </div>
          </:subtitle>
          <:actions>
            <%= if @is_creator and @game.status == "waiting" do %>
              <.button phx-click="delete_game" class="btn-ghost btn-error">
                Delete Game
              </.button>
            <% end %>
            <.button phx-click="leave_game" class="btn-ghost">
              Leave Game
            </.button>
            <%= if @is_creator do %>
              <.button
                phx-click="start_game"
                variant="primary"
                data-testid="start-game-button"
              >
                Start Game
              </.button>
            <% end %>
          </:actions>
        </.header>

        <div class="mt-8">
          <h2 class="text-lg font-semibold mb-4">
            Players (<%= length(@players) %>/4)
          </h2>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <%= for position <- 0..3 do %>
              <% player = Enum.find(@players, &(&1.position == position)) %>
              <% is_connected = player && (player.is_bot || MapSet.member?(@present_users, player.user_id)) %>
              <div class={[
                "bg-base-200 rounded-box p-6",
                player && "ring-2 ring-primary"
              ]}>
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-3 flex-1">
                    <div class={[
                      "avatar placeholder relative",
                      !player && "opacity-30"
                    ]}>
                      <div class="bg-neutral text-neutral-content rounded-full w-12">
                        <span class="text-xl">
                          <%= if player do %>
                            <%= if player.is_bot do %>
                              🤖
                            <% else %>
                              <%= String.first(player.user.username) |> String.upcase() %>
                            <% end %>
                          <% else %>
                            <%= position + 1 %>
                          <% end %>
                        </span>
                      </div>
                      <%= if player && !player.is_bot do %>
                        <div
                          class={[
                            "absolute -bottom-1 -right-1 w-4 h-4 rounded-full border-2 border-base-200",
                            is_connected && "bg-green-500",
                            !is_connected && "bg-red-500 animate-pulse"
                          ]}
                          title={is_connected && "Connecté" || "Déconnecté"}
                        >
                        </div>
                      <% end %>
                    </div>

                    <div class="flex-1">
                      <%= if player do %>
                        <%= if player.is_bot do %>
                          <div class="font-semibold">Bot</div>
                          <div class="text-sm text-base-content/60 capitalize">
                            <%= player.bot_difficulty %> difficulty
                          </div>
                        <% else %>
                          <div class="font-semibold flex items-center gap-2">
                            <%= player.user.username %>
                            <%= if player.user_id == @game.creator_id do %>
                              <span class="badge badge-sm badge-primary">Host</span>
                            <% end %>
                            <%= if player.user_id == @current_user.id do %>
                              <span class="badge badge-sm">You</span>
                            <% end %>
                            <%= if !is_connected do %>
                              <span class="badge badge-sm badge-error">Déconnecté</span>
                            <% end %>
                          </div>
                          <div class="text-sm text-base-content/60">
                            Position <%= position + 1 %>
                          </div>
                        <% end %>
                      <% else %>
                        <div class="text-base-content/40">Waiting for player...</div>
                        <div class="text-sm text-base-content/30">Position <%= position + 1 %></div>
                      <% end %>
                    </div>
                  </div>

                  <div class="flex gap-2">
                    <%= if player do %>
                      <%= if @is_creator and player.user_id != @game.creator_id do %>
                        <button
                          phx-click="remove_player"
                          phx-value-user-id={player.user_id}
                          class="btn btn-sm btn-ghost btn-circle"
                          title="Remove player"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M6 18L18 6M6 6l12 12"
                            />
                          </svg>
                        </button>
                      <% end %>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <%= if @is_creator do %>
            <div class="alert alert-info mt-6">
              <svg
                class="w-6 h-6 shrink-0"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <div class="text-sm">
                <p>You are the host. Share the room code <strong><%= @game.room_code %></strong> with friends to invite them.</p>
                <p class="mt-1">Empty slots will be automatically filled with bots when you start the game.</p>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
