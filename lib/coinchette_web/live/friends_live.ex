defmodule CoinchetteWeb.FriendsLive do
  use CoinchetteWeb, :live_view

  alias Coinchette.Friends
  alias CoinchetteWeb.Presence

  on_mount {CoinchetteWeb.Auth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    if connected?(socket) do
      # Track user as online
      Presence.track(self(), "users:online", user_id, %{
        username: socket.assigns.current_user.username
      })

      # Subscribe to friend events
      Phoenix.PubSub.subscribe(Coinchette.PubSub, "user:#{user_id}:friends")

      # Subscribe to presence diffs for online status
      Phoenix.PubSub.subscribe(Coinchette.PubSub, "users:online")
    end

    socket =
      socket
      |> assign(:page_title, "Amis")
      |> assign(:active_tab, "friends")
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:search_error, nil)
      |> load_friends_data()

    {:ok, socket}
  end

  defp load_friends_data(socket) do
    user_id = socket.assigns.current_user.id
    online_ids = if connected?(socket), do: Friends.online_friend_ids(user_id), else: MapSet.new()

    socket
    |> assign(:friends, Friends.list_friends(user_id))
    |> assign(:pending_requests, Friends.list_pending_requests(user_id))
    |> assign(:sent_requests, Friends.list_sent_requests(user_id))
    |> assign(:online_friend_ids, online_ids)
  end

  # Tab switching
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # Search
  def handle_event("search", %{"query" => query}, socket) do
    query = String.trim(query)

    if String.length(query) < 2 do
      {:noreply,
       socket
       |> assign(:search_results, [])
       |> assign(:search_error, nil)
       |> assign(:search_query, query)}
    else
      results = Friends.search_users(socket.assigns.current_user.id, query)

      {:noreply,
       socket
       |> assign(:search_results, results)
       |> assign(:search_error, nil)
       |> assign(:search_query, query)}
    end
  end

  # Send friend request
  def handle_event("add_friend", %{"username" => username}, socket) do
    case Friends.send_friend_request(socket.assigns.current_user.id, username) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Demande d'ami envoyée à #{username}")
         |> assign(:search_results, [])
         |> assign(:search_query, "")
         |> load_friends_data()}

      {:error, :already_pending} ->
        {:noreply, put_flash(socket, :error, "Demande déjà envoyée")}

      {:error, :already_friends} ->
        {:noreply, put_flash(socket, :error, "Vous êtes déjà amis")}

      {:error, :cannot_friend_self} ->
        {:noreply, put_flash(socket, :error, "Vous ne pouvez pas vous ajouter vous-même")}

      {:error, :user_not_found} ->
        {:noreply, put_flash(socket, :error, "Utilisateur introuvable")}
    end
  end

  # Accept friend request
  def handle_event("accept_request", %{"friend-id" => friend_id}, socket) do
    case Friends.accept_friend_request(socket.assigns.current_user.id, friend_id) do
      {:ok, :ok} ->
        {:noreply,
         socket
         |> put_flash(:info, "Demande acceptée !")
         |> load_friends_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erreur lors de l'acceptation")}
    end
  end

  # Decline friend request
  def handle_event("decline_request", %{"friend-id" => friend_id}, socket) do
    case Friends.decline_friend_request(socket.assigns.current_user.id, friend_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Demande refusée")
         |> load_friends_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erreur lors du refus")}
    end
  end

  # Cancel sent request
  def handle_event("cancel_request", %{"friend-id" => friend_id}, socket) do
    case Friends.cancel_friend_request(socket.assigns.current_user.id, friend_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Demande annulée")
         |> load_friends_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erreur lors de l'annulation")}
    end
  end

  # Remove friend
  def handle_event("remove_friend", %{"friend-id" => friend_id}, socket) do
    case Friends.remove_friend(socket.assigns.current_user.id, friend_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Ami supprimé")
         |> load_friends_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erreur lors de la suppression")}
    end
  end

  # PubSub handlers for real-time updates
  def handle_info({:friend_request_received, _}, socket) do
    {:noreply, load_friends_data(socket)}
  end

  def handle_info({:friend_request_accepted, _}, socket) do
    {:noreply, load_friends_data(socket)}
  end

  def handle_info({:friend_removed, _}, socket) do
    {:noreply, load_friends_data(socket)}
  end

  # Presence diff for online status changes
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    online_ids = Friends.online_friend_ids(socket.assigns.current_user.id)
    {:noreply, assign(socket, :online_friend_ids, online_ids)}
  end

  def render(assigns) do
    pending_count = length(assigns.pending_requests)

    assigns = assign(assigns, :pending_count, pending_count)

    ~H"""
    <div>
      <div class="mx-auto max-w-2xl px-2 sm:px-4 md:px-6 lg:px-8 pb-20 sm:pb-0">
        <!-- Header -->
        <div class="flex items-center justify-between py-6">
          <div class="flex items-center gap-3">
            <.link navigate={~p"/lobby"} class="btn btn-ghost btn-sm btn-circle">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
            </.link>
            <h1 class="text-2xl sm:text-3xl font-bold">Amis</h1>
          </div>
        </div>

        <!-- Tabs -->
        <div class="tabs tabs-boxed mb-6 bg-base-200" data-testid="friends-tabs">
          <button
            phx-click="switch_tab"
            phx-value-tab="friends"
            class={["tab flex-1", @active_tab == "friends" && "tab-active"]}
            data-testid="tab-friends"
          >
            Mes amis
            <span :if={length(@friends) > 0} class="badge badge-sm ml-1">{length(@friends)}</span>
          </button>
          <button
            phx-click="switch_tab"
            phx-value-tab="requests"
            class={["tab flex-1", @active_tab == "requests" && "tab-active"]}
            data-testid="tab-requests"
          >
            Demandes
            <span :if={@pending_count > 0} class="badge badge-sm badge-primary ml-1">{@pending_count}</span>
          </button>
          <button
            phx-click="switch_tab"
            phx-value-tab="search"
            class={["tab flex-1", @active_tab == "search" && "tab-active"]}
            data-testid="tab-search"
          >
            Rechercher
          </button>
        </div>

        <!-- Tab Content -->
        <div :if={@active_tab == "friends"}>
          <%= if Enum.empty?(@friends) do %>
            <div class="text-center py-12 text-base-content/60">
              <div class="text-4xl mb-4">👥</div>
              <p class="text-lg mb-2">Pas encore d'amis</p>
              <p class="text-sm">Recherchez des joueurs pour les ajouter !</p>
              <button phx-click="switch_tab" phx-value-tab="search" class="btn btn-primary btn-sm mt-4">
                Rechercher
              </button>
            </div>
          <% else %>
            <div class="space-y-2">
              <%= for friend <- @friends do %>
                <div class="card bg-base-200 p-4 flex flex-row items-center justify-between" data-testid="friend-entry">
                  <div class="flex items-center gap-3">
                    <div class={[
                      "w-3 h-3 rounded-full",
                      MapSet.member?(@online_friend_ids, friend.friend_id) && "bg-success",
                      !MapSet.member?(@online_friend_ids, friend.friend_id) && "bg-base-content/20"
                    ]}>
                    </div>
                    <span class="font-medium">{friend.username}</span>
                    <span
                      :if={MapSet.member?(@online_friend_ids, friend.friend_id)}
                      class="text-xs text-success"
                    >
                      En ligne
                    </span>
                  </div>
                  <button
                    phx-click="remove_friend"
                    phx-value-friend-id={friend.friend_id}
                    data-confirm="Supprimer cet ami ?"
                    class="btn btn-ghost btn-sm text-error"
                  >
                    Supprimer
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div :if={@active_tab == "requests"}>
          <!-- Received requests -->
          <h3 class="font-semibold text-lg mb-3">Demandes reçues</h3>
          <%= if Enum.empty?(@pending_requests) do %>
            <p class="text-base-content/60 text-sm mb-6">Aucune demande en attente</p>
          <% else %>
            <div class="space-y-2 mb-6">
              <%= for request <- @pending_requests do %>
                <div class="card bg-base-200 p-4 flex flex-row items-center justify-between">
                  <div>
                    <span class="font-medium">{request.username}</span>
                  </div>
                  <div class="flex gap-2">
                    <button
                      phx-click="accept_request"
                      phx-value-friend-id={request.friend_id}
                      class="btn btn-success btn-sm"
                      data-testid="accept-request-button"
                    >
                      Accepter
                    </button>
                    <button
                      phx-click="decline_request"
                      phx-value-friend-id={request.friend_id}
                      class="btn btn-ghost btn-sm"
                      data-testid="decline-request-button"
                    >
                      Refuser
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Sent requests -->
          <h3 class="font-semibold text-lg mb-3">Demandes envoyées</h3>
          <%= if Enum.empty?(@sent_requests) do %>
            <p class="text-base-content/60 text-sm">Aucune demande envoyée</p>
          <% else %>
            <div class="space-y-2">
              <%= for request <- @sent_requests do %>
                <div class="card bg-base-200 p-4 flex flex-row items-center justify-between">
                  <div>
                    <span class="font-medium">{request.username}</span>
                    <span class="badge badge-warning badge-sm ml-2">En attente</span>
                  </div>
                  <button
                    phx-click="cancel_request"
                    phx-value-friend-id={request.friend_id}
                    class="btn btn-ghost btn-sm"
                  >
                    Annuler
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div :if={@active_tab == "search"}>
          <.form for={%{}} phx-submit="search" phx-change="search" class="mb-6">
            <div class="flex gap-2">
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Rechercher par nom d'utilisateur..."
                class="input input-bordered flex-1"
                autocomplete="off"
                phx-debounce="300"
                data-testid="search-input"
              />
              <button type="submit" class="btn btn-primary" data-testid="search-button">
                Rechercher
              </button>
            </div>
          </.form>

          <%= if @search_error do %>
            <div class="alert alert-error mb-4">
              <span>{@search_error}</span>
            </div>
          <% end %>

          <%= if !Enum.empty?(@search_results) do %>
            <div class="space-y-2">
              <%= for user <- @search_results do %>
                <div class="card bg-base-200 p-4 flex flex-row items-center justify-between">
                  <span class="font-medium">{user.username}</span>
                  <button
                    phx-click="add_friend"
                    phx-value-username={user.username}
                    class="btn btn-primary btn-sm"
                    data-testid="add-friend-button"
                  >
                    Ajouter
                  </button>
                </div>
              <% end %>
            </div>
          <% else %>
            <%= if String.length(@search_query) >= 2 do %>
              <p class="text-center text-base-content/60 py-8">Aucun résultat</p>
            <% else %>
              <p class="text-center text-base-content/60 py-8">
                Entrez au moins 2 caractères pour rechercher
              </p>
            <% end %>
          <% end %>
        </div>
      </div>

      <!-- Bottom Navigation (mobile) -->
      <div class="block sm:hidden">
        <CoinchetteWeb.BottomNav.bottom_nav current_path="/friends" />
      </div>
    </div>
    """
  end
end
