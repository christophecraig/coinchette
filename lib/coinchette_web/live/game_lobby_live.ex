defmodule CoinchetteWeb.GameLobbyLive do
  use CoinchetteWeb, :live_view

  alias Coinchette.{Multiplayer, GameServer, GameServerSupervisor, Friends}
  alias Coinchette.Notifications.GameNotifications
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

          # Track user presence in lobby (ignore if already tracked)
          case Presence.track(self(), "game:#{game_id}", socket.assigns.current_user.id, %{
                 username: socket.assigns.current_user.username,
                 joined_at: System.system_time(:second)
               }) do
            {:ok, _} ->
              :ok

            {:error, {:already_tracked, _, _, _}} ->
              :ok

            {:error, reason} ->
              require Logger
              Logger.warning("Failed to track presence: #{inspect(reason)}")
          end

          # Track user as online for friends system
          Presence.track(self(), "users:online", socket.assigns.current_user.id, %{
            username: socket.assigns.current_user.username
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
        |> assign(:show_invite_modal, false)
        |> assign(:online_friends, [])
        |> load_players()
      else
        # User is not in the game - auto-join when connected
        if connected?(socket) do
          # Ensure GameServer is running
          case GameServerSupervisor.start_game(game_id) do
            {:ok, _pid} -> :ok
            {:error, {:already_started, _pid}} -> :ok
          end

          send(self(), :auto_join)
        end

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
            # Subscribe to game events (ignore if already subscribed)
            Phoenix.PubSub.subscribe(Coinchette.PubSub, "game:#{game_id}")
            require Logger
            Logger.info("Player #{user_id} subscribed to game:#{game_id}")

            # Track user presence in lobby (ignore if already tracked)
            case Presence.track(self(), "game:#{game_id}", user_id, %{
                   username: socket.assigns.current_user.username,
                   joined_at: System.system_time(:second)
                 }) do
              {:ok, _} -> :ok
              {:error, {:already_tracked, _, _, _}} -> :ok
              {:error, reason} -> Logger.warning("Failed to track presence: #{inspect(reason)}")
            end

            # Reload game state
            game = Multiplayer.get_game!(game_id)

            {:noreply,
             socket
             |> assign(:game, game)
             |> assign(:joining, false)
             |> assign(:is_creator, game.creator_id == user_id)
             |> assign(:present_users, get_present_users(game_id))
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

  def handle_event("update_target_score", %{"target_score" => target_score_str}, socket) do
    if socket.assigns.is_creator and socket.assigns.game.status == "waiting" do
      target_score = String.to_integer(target_score_str)

      case Multiplayer.update_game_settings(socket.assigns.game_id, %{
             target_score: target_score
           }) do
        {:ok, updated_game} ->
          # Broadcast so other clients in lobby see the update
          Phoenix.PubSub.broadcast(
            Coinchette.PubSub,
            "game:#{socket.assigns.game_id}",
            {:settings_updated, %{target_score: target_score}}
          )

          {:noreply,
           socket
           |> assign(:game, updated_game)
           |> put_flash(:info, "Target score updated to #{target_score}")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to update target score")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only the host can change game settings")}
    end
  end

  def handle_event("start_game", _params, socket) do
    if socket.assigns.is_creator do
      # Vérifier équilibre des équipes
      if not socket.assigns.is_balanced do
        {:noreply, put_flash(socket, :error, "Chaque équipe peut contenir maximum 2 joueurs")}
      else
        game_id = socket.assigns.game_id

        # Ensure GameServer is running before starting the game
        with {:ok, _} <- ensure_game_server_started(game_id),
             {:ok, _game} <- GameServer.start_game(game_id) do
          {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}/play")}
        else
          {:error, :not_enough_players} ->
            {:noreply, put_flash(socket, :error, "Besoin d'au moins 2 joueurs pour démarrer")}

          {:error, :server_not_available} ->
            {:noreply, put_flash(socket, :error, "Erreur technique, veuillez réessayer")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Échec du démarrage de la partie")}
        end
      end
    else
      {:noreply, put_flash(socket, :error, "Only the host can start the game")}
    end
  end

  def handle_event(
        "move_player_to_team",
        %{"position" => position_str, "target-team" => target_team_str},
        socket
      ) do
    # Vérifier que c'est l'hôte
    if not socket.assigns.is_creator do
      {:noreply, put_flash(socket, :error, "Seul l'hôte peut réorganiser les équipes")}
    else
      current_position = String.to_integer(position_str)
      target_team = String.to_integer(target_team_str)
      current_team = rem(current_position, 2)

      if current_team == target_team do
        # Déjà dans la bonne équipe
        {:noreply, socket}
      else
        # Trouver une position disponible dans l'équipe cible
        target_positions = if target_team == 0, do: [0, 2], else: [1, 3]
        occupied_positions = Enum.map(socket.assigns.players, & &1.position)

        case Enum.find(target_positions, &(&1 not in occupied_positions)) do
          nil ->
            {:noreply, put_flash(socket, :error, "Aucune place disponible dans cette équipe")}

          new_position ->
            case GameServer.change_player_position(
                   socket.assigns.game_id,
                   current_position,
                   new_position
                 ) do
              :ok ->
                {:noreply, socket}

              {:error, :game_already_started} ->
                {:noreply, put_flash(socket, :error, "La partie a déjà commencé")}

              {:error, :position_taken} ->
                {:noreply, put_flash(socket, :error, "Cette position est déjà prise")}

              {:error, _} ->
                {:noreply, put_flash(socket, :error, "Erreur lors du déplacement")}
            end
        end
      end
    end
  end

  def handle_event("show_invite_modal", _params, socket) do
    user_id = socket.assigns.current_user.id
    online_ids = Friends.online_friend_ids(user_id)
    friends = Friends.list_friends(user_id)

    online_friends =
      friends
      |> Enum.filter(fn f -> MapSet.member?(online_ids, f.friend_id) end)

    {:noreply,
     socket
     |> assign(:show_invite_modal, true)
     |> assign(:online_friends, online_friends)}
  end

  def handle_event("close_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, false)}
  end

  def handle_event("invite_friend", %{"friend-id" => friend_id, "username" => username}, socket) do
    GameNotifications.notify_game_invite(
      friend_id,
      socket.assigns.current_user.username,
      socket.assigns.game_id
    )

    Phoenix.PubSub.broadcast(
      Coinchette.PubSub,
      "user:#{friend_id}:game_invites",
      {:game_invite_received,
       %{
         from_username: socket.assigns.current_user.username,
         game_id: socket.assigns.game_id
       }}
    )

    {:noreply,
     socket
     |> put_flash(:info, "Invitation envoyée à #{username}")
     |> assign(:show_invite_modal, false)}
  end

  # Auto-join handler
  def handle_info(:auto_join, socket) do
    game_id = socket.assigns.game_id
    user_id = socket.assigns.current_user.id
    game = Multiplayer.get_game!(game_id)

    case find_available_position(game) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "La partie est pleine")
         |> push_navigate(to: ~p"/lobby")}

      position ->
        case GameServer.add_player(game_id, user_id, position) do
          :ok ->
            # Subscribe to game events
            Phoenix.PubSub.subscribe(Coinchette.PubSub, "game:#{game_id}")

            # Track user presence
            case Presence.track(self(), "game:#{game_id}", user_id, %{
                   username: socket.assigns.current_user.username,
                   joined_at: System.system_time(:second)
                 }) do
              {:ok, _} -> :ok
              {:error, {:already_tracked, _, _, _}} -> :ok
              {:error, _reason} -> :ok
            end

            # Reload game state and switch to lobby view
            game = Multiplayer.get_game!(game_id)

            {:noreply,
             socket
             |> assign(:game, game)
             |> assign(:joining, false)
             |> assign(:is_creator, game.creator_id == user_id)
             |> assign(:present_users, get_present_users(game_id))
             |> load_players()
             |> put_flash(:info, "Vous avez rejoint la partie !")}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Impossible de rejoindre la partie")
             |> push_navigate(to: ~p"/lobby")}
        end
    end
  end

  # PubSub event handlers
  def handle_info({:player_joined, _data}, socket) do
    {:noreply, reload_game_state(socket)}
  end

  def handle_info({:player_left, %{user_id: user_id}}, socket) do
    # If the current user was removed, redirect them to lobby
    if user_id == socket.assigns.current_user.id do
      {:noreply,
       socket
       |> put_flash(:info, "You have been removed from the game")
       |> push_navigate(to: ~p"/lobby")}
    else
      {:noreply, reload_game_state(socket)}
    end
  end

  def handle_info({:player_moved, _data}, socket) do
    {:noreply, reload_game_state(socket)}
  end

  def handle_info({:settings_updated, _data}, socket) do
    {:noreply, reload_game_state(socket)}
  end

  def handle_info({:game_started, _game}, socket) do
    require Logger

    Logger.info(
      "Received game_started event for user #{socket.assigns.current_user.id}, redirecting to play"
    )

    {:noreply, push_navigate(socket, to: ~p"/game/#{socket.assigns.game_id}/play")}
  end

  def handle_info({:game_updated, _game}, socket) do
    # Ignore game updates in the lobby - we only care about game_started
    {:noreply, socket}
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

  defp ensure_game_server_started(game_id) do
    case GameServerSupervisor.start_game(game_id) do
      {:ok, _pid} ->
        {:ok, :started}

      {:error, {:already_started, _pid}} ->
        {:ok, :already_started}

      {:error, reason} ->
        require Logger
        Logger.error("Failed to start GameServer for game #{game_id}: #{inspect(reason)}")
        {:error, :server_not_available}
    end
  end

  defp get_present_users(game_id) do
    Presence.list("game:#{game_id}")
    |> Map.keys()
    |> MapSet.new()
  end

  defp load_players(socket) do
    players = Multiplayer.list_game_players(socket.assigns.game_id)

    socket
    |> assign(:players, players)
    |> assign_teams()
  end

  defp assign_teams(socket) do
    players = socket.assigns.players

    team_0 = Enum.filter(players, &(rem(&1.position, 2) == 0)) |> Enum.sort_by(& &1.position)
    team_1 = Enum.filter(players, &(rem(&1.position, 2) == 1)) |> Enum.sort_by(& &1.position)

    # Nouvelle logique: autoriser 0, 1 ou 2 joueurs par équipe
    # Les bots compléteront automatiquement
    team_0_valid = length(team_0) <= 2
    team_1_valid = length(team_1) <= 2
    is_balanced = team_0_valid and team_1_valid

    socket
    |> assign(:team_0, team_0)
    |> assign(:team_1, team_1)
    |> assign(:is_balanced, is_balanced)
  end

  defp is_user_in_game?(game, user_id) do
    Enum.any?(game.game_players, fn player -> player.user_id == user_id end)
  end

  defp find_available_position(game) do
    occupied_positions = Enum.map(game.game_players, & &1.position) |> MapSet.new()

    Enum.find(0..3, fn pos -> !MapSet.member?(occupied_positions, pos) end)
  end

  defp render_player_card(
         player,
         current_user,
         creator_id,
         is_creator,
         present_users,
         team_number
       ) do
    assigns = %{
      player: player,
      current_user: current_user,
      creator_id: creator_id,
      is_creator: is_creator,
      is_connected: player.is_bot || MapSet.member?(present_users, player.user_id),
      is_current_user: player.user_id == current_user.id,
      other_team: if(team_number == 1, do: 2, else: 1)
    }

    ~H"""
    <div class="p-4 bg-base-100 rounded-lg flex items-center justify-between gap-3">
      <div class="flex items-center gap-3 flex-1 min-w-0">
        <!-- Avatar -->
        <div class="avatar placeholder relative">
          <div class="bg-primary text-primary-content rounded-full w-10 h-10 sm:w-12 sm:h-12">
            <span class="text-lg sm:text-xl">
              <%= if @player.is_bot do %>
                🤖
              <% else %>
                {String.upcase(String.first(@player.user.username))}
              <% end %>
            </span>
          </div>
          <%= if !@player.is_bot do %>
            <div
              class={[
                "absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full border-2 border-base-100",
                @is_connected && "bg-success",
                !@is_connected && "bg-error"
              ]}
              title={if @is_connected, do: "Connecté", else: "Déconnecté"}
            >
            </div>
          <% end %>
        </div>
        <!-- Info -->
        <div class="flex-1 min-w-0">
          <div class="font-semibold flex flex-wrap items-center gap-1 sm:gap-2 text-sm sm:text-base">
            <span class="truncate">
              <%= if @player.is_bot do %>
                Bot
              <% else %>
                {@player.user.username}
              <% end %>
            </span>
            <%= if @is_current_user do %>
              <span class="badge badge-xs sm:badge-sm badge-primary">Vous</span>
            <% end %>
            <%= if @player.user_id == @creator_id do %>
              <span class="badge badge-xs sm:badge-sm badge-accent">Hôte</span>
            <% end %>
          </div>

          <%= if @player.is_bot do %>
            <div class="text-xs sm:text-sm text-base-content/70">
              <%= case @player.bot_difficulty do %>
                <% "easy" -> %>
                  🐌 Facile
                <% "medium" -> %>
                  ⚡ Moyen
                <% "hard" -> %>
                  🔥 Difficile
                <% _ -> %>
                  Bot
              <% end %>
            </div>
          <% else %>
            <div class="flex items-center gap-1 text-xs sm:text-sm">
              <span class={"inline-block w-2 h-2 rounded-full #{if @is_connected, do: "bg-success", else: "bg-error"}"}>
              </span>
              {if @is_connected, do: "Connecté", else: "Déconnecté"}
            </div>
          <% end %>
        </div>
      </div>
      <!-- Boutons d'action -->
      <div class="flex gap-2 flex-shrink-0">
        <%= if @is_creator do %>
          <button
            phx-click="move_player_to_team"
            phx-value-position={@player.position}
            phx-value-target-team={@other_team - 1}
            class="btn btn-xs sm:btn-sm btn-outline gap-1"
            title={"Déplacer vers Équipe #{@other_team}"}
          >
            <%= if @other_team == 1 do %>
              <span class="hidden sm:inline">← Équipe 1</span>
              <span class="sm:hidden">←</span>
            <% else %>
              <span class="hidden sm:inline">Équipe 2 →</span>
              <span class="sm:hidden">→</span>
            <% end %>
          </button>
        <% end %>
        <%= if @is_creator and @player.user_id != @creator_id do %>
          <button
            phx-click="remove_player"
            phx-value-user-id={@player.user_id || ""}
            class="btn btn-xs sm:btn-sm btn-ghost btn-circle"
            title="Retirer le joueur"
          >
            <svg class="w-3 h-3 sm:w-4 sm:h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-2 sm:px-4 md:px-6 lg:px-8">
      <%= if assigns[:joining] do %>
        <!-- Auto-joining in progress -->
        <div class="text-center py-8 sm:py-12 px-2">
          <.header>
            Rejoindre {@game.room_code}
          </.header>

          <div class="mt-6 sm:mt-8 bg-base-200 rounded-box p-6 sm:p-8">
            <p class="text-base sm:text-lg mb-4">
              Connexion en cours...
            </p>
            <span class="loading loading-spinner loading-lg"></span>
            <div class="mt-4">
              <.link navigate="/lobby" class="text-xs sm:text-sm text-base-content/60 hover:underline">
                Retour au lobby
              </.link>
            </div>
          </div>
        </div>
      <% else %>
        <!-- Game lobby view for players -->
        <.header>
          Game Lobby
          <:subtitle>
            <div class="flex flex-wrap items-center gap-2 sm:gap-3">
              <span class="text-xs sm:text-sm">Room Code:</span>
              <span class="badge badge-md sm:badge-lg font-mono text-base sm:text-lg px-3 sm:px-4">
                {@game.room_code}
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
              <.button phx-click="delete_game" class="btn-ghost btn-error btn-sm sm:btn-md">
                <span class="hidden sm:inline">Delete Game</span>
                <span class="sm:hidden">Delete</span>
              </.button>
            <% end %>
            <.button phx-click="leave_game" class="btn-ghost btn-sm sm:btn-md">
              <span class="hidden sm:inline">Leave Game</span>
              <span class="sm:hidden">Leave</span>
            </.button>
            <%= if @is_creator do %>
              <.button
                phx-click="start_game"
                variant="primary"
                data-testid="start-game-button"
                class={"w-full sm:w-auto #{if not @is_balanced, do: "btn-disabled"}"}
                disabled={not @is_balanced}
              >
                <%= if @is_balanced do %>
                  Démarrer la partie
                <% else %>
                  Max 2 joueurs par équipe
                <% end %>
              </.button>
            <% end %>
          </:actions>
        </.header>
        
    <!-- Game Settings -->
        <div class="mt-6 sm:mt-8 bg-base-200 rounded-box p-4 sm:p-6">
          <h2 class="text-base sm:text-lg font-semibold mb-4">Game Settings</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3 sm:gap-4">
            <div>
              <label class="label">
                <span class="label-text font-medium">Target Score</span>
              </label>
              <%= if @is_creator and @game.status == "waiting" do %>
                <form phx-change="update_target_score">
                  <select
                    class="select select-bordered w-full"
                    name="target_score"
                  >
                    <option value="500" selected={@game.target_score == 500}>500 points</option>
                    <option value="1000" selected={@game.target_score == 1000}>
                      1000 points (default)
                    </option>
                  </select>
                </form>
              <% else %>
                <div class="text-lg font-semibold">
                  {@game.target_score} points
                </div>
              <% end %>
              <p class="text-sm text-base-content/60 mt-2">
                First team to reach this score wins the game
              </p>
            </div>
            <div>
              <label class="label">
                <span class="label-text font-medium">Game Variant</span>
              </label>
              <div class="text-lg font-semibold capitalize">
                {@game.variant}
              </div>
              <p class="text-sm text-base-content/60 mt-2">
                The game will be played with {@game.variant} rules
              </p>
            </div>
          </div>
        </div>
        
    <!-- Section équipes -->
        <div class="mt-6 sm:mt-8">
          <h2 class="text-base sm:text-lg font-semibold mb-4">
            Composition des équipes ({length(@players)}/4)
          </h2>

          <%= if not @is_balanced do %>
            <div class="alert alert-warning mb-4">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                />
              </svg>
              <span class="text-sm">
                Chaque équipe peut contenir maximum 2 joueurs. Les positions vides seront remplies par des bots.
              </span>
            </div>
          <% end %>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <!-- Équipe 1 (Team 0) -->
            <div class="card bg-base-200">
              <div class="card-body p-4">
                <h3 class="card-title text-blue-400 text-base sm:text-lg">Équipe 1</h3>

                <%= for position <- [0, 2] do %>
                  <% player = Enum.find(@players, &(&1.position == position)) %>
                  <%= if player do %>
                    {render_player_card(
                      player,
                      @current_user,
                      @game.creator_id,
                      @is_creator,
                      @present_users,
                      1
                    )}
                  <% else %>
                    <div class="p-4 border-2 border-dashed border-base-300 rounded-lg text-center text-base-content/50">
                      Position {position + 1} - Vide
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
            
    <!-- Équipe 2 (Team 1) -->
            <div class="card bg-base-200">
              <div class="card-body p-4">
                <h3 class="card-title text-orange-400 text-base sm:text-lg">Équipe 2</h3>

                <%= for position <- [1, 3] do %>
                  <% player = Enum.find(@players, &(&1.position == position)) %>
                  <%= if player do %>
                    {render_player_card(
                      player,
                      @current_user,
                      @game.creator_id,
                      @is_creator,
                      @present_users,
                      2
                    )}
                  <% else %>
                    <div class="p-4 border-2 border-dashed border-base-300 rounded-lg text-center text-base-content/50">
                      Position {position + 1} - Vide
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Invite friends button -->
          <div class="mt-4 sm:mt-6 flex justify-center">
            <button phx-click="show_invite_modal" class="btn btn-primary btn-sm sm:btn-md gap-2">
              <svg class="w-4 h-4 sm:w-5 sm:h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
              </svg>
              Inviter des amis
            </button>
          </div>

          <%= if @is_creator do %>
            <div class="alert alert-info mt-4 sm:mt-6">
              <svg
                class="w-5 h-5 sm:w-6 sm:h-6 shrink-0"
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
              <div class="text-xs sm:text-sm">
                <p>
                  Vous êtes l'hôte. Partagez le code <strong>{@game.room_code}</strong>
                  avec vos amis pour les inviter.
                </p>
                <p class="mt-1">
                  Les positions vides seront automatiquement remplies par des bots au démarrage.
                </p>
                <p class="mt-1">
                  Utilisez les boutons pour déplacer les joueurs entre les équipes.
                </p>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Invite friends modal -->
      <%= if @show_invite_modal do %>
        <div class="modal modal-open" phx-window-keydown="close_invite_modal" phx-key="Escape">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Inviter des amis</h3>

            <%= if Enum.empty?(@online_friends) do %>
              <p class="text-base-content/60 text-center py-6">
                Aucun ami en ligne pour le moment
              </p>
              <p class="text-sm text-base-content/40 text-center">
                <.link navigate={~p"/friends"} class="link link-primary">
                  Ajouter des amis
                </.link>
              </p>
            <% else %>
              <div class="space-y-2">
                <%= for friend <- @online_friends do %>
                  <div class="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                    <div class="flex items-center gap-2">
                      <div class="w-2.5 h-2.5 rounded-full bg-success"></div>
                      <span class="font-medium">{friend.username}</span>
                    </div>
                    <button
                      phx-click="invite_friend"
                      phx-value-friend-id={friend.friend_id}
                      phx-value-username={friend.username}
                      class="btn btn-primary btn-sm"
                    >
                      Inviter
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>

            <div class="modal-action">
              <button phx-click="close_invite_modal" class="btn">Fermer</button>
            </div>
          </div>
          <div class="modal-backdrop" phx-click="close_invite_modal"></div>
        </div>
      <% end %>
    </div>
    """
  end
end
