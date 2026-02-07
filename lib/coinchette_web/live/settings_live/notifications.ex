defmodule CoinchetteWeb.SettingsLive.Notifications do
  @moduledoc """
  LiveView for managing push notification settings.
  """
  use CoinchetteWeb, :live_view

  alias Coinchette.Notifications

  on_mount {CoinchetteWeb.Auth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_user] do
      subscriptions = Notifications.list_user_subscriptions(socket.assigns.current_user.id)

      {:ok,
       socket
       |> assign(:page_title, "Notification Settings")
       |> assign(:subscriptions, subscriptions)
       |> assign(:push_supported, false)
       |> assign(:push_unsupported_reason, nil)
       |> assign(:push_debug, nil)
       |> assign(:push_permission, "default")
       |> assign(:push_subscribed, false)
       |> assign(:error, nil)
       |> assign(:success, nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to manage notifications")
       |> redirect(to: ~p"/login")}
    end
  end

  @impl true
  def handle_event("push_state_initialized", state, socket) do
    {:noreply,
     socket
     |> assign(:push_supported, state["supported"] || false)
     |> assign(:push_unsupported_reason, state["reason"])
     |> assign(:push_debug, state["details"])
     |> assign(:push_permission, state["permission"] || "default")
     |> assign(:push_subscribed, state["subscribed"] || false)}
  end

  @impl true
  def handle_event("push_subscription_created", params, socket) do
    subscription_data = params["subscription"]
    user_agent = params["user_agent"]

    case Notifications.subscribe_user(socket.assigns.current_user.id, %{
           "endpoint" => subscription_data["endpoint"],
           "keys" => subscription_data["keys"],
           "user_agent" => user_agent
         }) do
      {:ok, _subscription} ->
        subscriptions = Notifications.list_user_subscriptions(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:subscriptions, subscriptions)
         |> assign(:push_subscribed, true)
         |> assign(:success, "Push notifications enabled!")
         |> assign(:error, nil)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:error, "Failed to enable push notifications: #{inspect(changeset.errors)}")
         |> assign(:success, nil)}
    end
  end

  @impl true
  def handle_event("push_subscription_deleted", params, socket) do
    endpoint = params["endpoint"]

    Notifications.unsubscribe_user(socket.assigns.current_user.id, endpoint)

    subscriptions = Notifications.list_user_subscriptions(socket.assigns.current_user.id)

    {:noreply,
     socket
     |> assign(:subscriptions, subscriptions)
     |> assign(:push_subscribed, false)
     |> assign(:success, "Push notifications disabled")
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("push_subscription_error", params, socket) do
    {:noreply,
     socket
     |> assign(:error, params["error"])
     |> assign(:success, nil)}
  end

  @impl true
  def handle_event("test_notification", _params, socket) do
    user_id = socket.assigns.current_user.id

    payload = %{
      title: "Test Coinchette",
      body: "Les notifications push fonctionnent !",
      icon: "/images/icon-192.png",
      badge: "/images/icon-96.png",
      tag: "test-#{System.system_time(:second)}",
      requireInteraction: false,
      data: %{type: "test"}
    }

    case Notifications.send_notification(user_id, :game_invite, payload) do
      {:ok, count} when count > 0 ->
        {:noreply, assign(socket, success: "Notification envoyée !", error: nil)}

      _ ->
        {:noreply,
         assign(socket,
           error: "Aucun appareil n'a reçu la notification. Vérifiez votre abonnement.",
           success: nil
         )}
    end
  end

  @impl true
  def handle_event("update_preferences", params, socket) do
    subscription_id = params["subscription_id"]

    preferences = %{
      notify_game_invite: params["notify_game_invite"] == "true",
      notify_your_turn: params["notify_your_turn"] == "true",
      notify_game_result: params["notify_game_result"] == "true",
      notify_chat_message: params["notify_chat_message"] == "true"
    }

    case Notifications.update_preferences(
           subscription_id,
           socket.assigns.current_user.id,
           preferences
         ) do
      {:ok, _subscription} ->
        subscriptions = Notifications.list_user_subscriptions(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:subscriptions, subscriptions)
         |> assign(:success, "Preferences updated!")
         |> assign(:error, nil)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:error, "Failed to update preferences")
         |> assign(:success, nil)}
    end
  end

  @impl true
  def handle_event("deactivate_subscription", %{"id" => id}, socket) do
    case Notifications.deactivate_subscription(id) do
      {:ok, _} ->
        subscriptions = Notifications.list_user_subscriptions(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:subscriptions, subscriptions)
         |> assign(:success, "Subscription removed")
         |> assign(:error, nil)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:error, "Failed to remove subscription")
         |> assign(:success, nil)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8 py-8">
      <.header>
        <:title>Notification Settings</:title>
        <:subtitle>Manage your push notification preferences</:subtitle>
      </.header>

      <%= if @error do %>
        <div class="mt-4 rounded-md bg-red-50 p-4">
          <p class="text-sm text-red-800"><%= @error %></p>
        </div>
      <% end %>

      <%= if @success do %>
        <div class="mt-4 rounded-md bg-green-50 p-4">
          <p class="text-sm text-green-800"><%= @success %></p>
        </div>
      <% end %>

      <div
        id="push-notification-manager"
        class="mt-8"
        phx-hook="PushNotification"
        data-vapid-public-key={Application.get_env(:coinchette, :vapid_public_key)}
      >
        <!-- Hook will populate this with push API diagnostics -->
        <div id="push-debug-info" class="mb-4 rounded-md bg-gray-100 p-3 text-xs font-mono text-gray-600">
          Chargement des diagnostics...
        </div>
        <%= if not @push_supported do %>
          <div class="rounded-md bg-yellow-50 p-4">
            <%= if @push_unsupported_reason == "not_standalone" do %>
              <p class="text-sm text-yellow-800 font-medium">
                Les notifications push nécessitent l'installation de l'application.
              </p>
              <p class="text-sm text-yellow-700 mt-2">
                Sur iOS : ouvrez le site dans Safari, appuyez sur le bouton de partage, puis "Sur l'écran d'accueil". Supprimez d'abord l'ancien raccourci si nécessaire.
              </p>
            <% else %>
              <p class="text-sm text-yellow-800">
                Les notifications push ne sont pas supportées sur ce navigateur ou appareil.
              </p>
            <% end %>
          </div>
        <% else %>
          <div class="space-y-6">
            <!-- Enable/Disable Push Notifications -->
            <div class="rounded-lg border border-gray-200 bg-white p-6">
              <h3 class="text-lg font-medium text-gray-900">Push Notifications</h3>
              <p class="mt-1 text-sm text-gray-500">
                Receive notifications even when Coinchette is closed
              </p>

              <div class="mt-4">
                <%= if @push_subscribed do %>
                  <button
                    type="button"
                    phx-click={JS.push("unsubscribe_push")}
                    class="rounded-md bg-red-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-red-500"
                  >
                    Disable Push Notifications
                  </button>
                <% else %>
                  <button
                    type="button"
                    phx-click={JS.push("subscribe_push")}
                    class="rounded-md bg-green-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-green-500"
                  >
                    Enable Push Notifications
                  </button>
                <% end %>

                <%= if @push_subscribed do %>
                  <button
                    type="button"
                    phx-click="test_notification"
                    class="ml-3 rounded-md bg-gray-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-gray-500"
                  >
                    Test Notification
                  </button>
                <% end %>
              </div>
            </div>

            <!-- Active Subscriptions -->
            <%= if @subscriptions != [] do %>
              <div class="rounded-lg border border-gray-200 bg-white p-6">
                <h3 class="text-lg font-medium text-gray-900">Active Devices</h3>
                <p class="mt-1 text-sm text-gray-500">
                  Manage notifications for each device
                </p>

                <div class="mt-4 space-y-4">
                  <%= for subscription <- @subscriptions do %>
                    <div class="rounded-lg border border-gray-100 bg-gray-50 p-4">
                      <div class="flex items-start justify-between">
                        <div class="flex-1">
                          <p class="text-sm font-medium text-gray-900">
                            <%= extract_device_info(subscription.user_agent) %>
                          </p>
                          <p class="text-xs text-gray-500">
                            Added <%= Calendar.strftime(subscription.inserted_at, "%B %d, %Y") %>
                          </p>
                        </div>

                        <button
                          type="button"
                          phx-click="deactivate_subscription"
                          phx-value-id={subscription.id}
                          class="text-sm text-red-600 hover:text-red-800"
                        >
                          Remove
                        </button>
                      </div>

                      <div class="mt-4 space-y-2">
                        <label class="flex items-center">
                          <input
                            type="checkbox"
                            checked={subscription.notify_game_invite}
                            phx-click="update_preferences"
                            phx-value-subscription_id={subscription.id}
                            phx-value-notify_game_invite={!subscription.notify_game_invite}
                            phx-value-notify_your_turn={subscription.notify_your_turn}
                            phx-value-notify_game_result={subscription.notify_game_result}
                            phx-value-notify_chat_message={subscription.notify_chat_message}
                            class="rounded"
                          />
                          <span class="ml-2 text-sm text-gray-700">Game invitations</span>
                        </label>

                        <label class="flex items-center">
                          <input
                            type="checkbox"
                            checked={subscription.notify_your_turn}
                            phx-click="update_preferences"
                            phx-value-subscription_id={subscription.id}
                            phx-value-notify_game_invite={subscription.notify_game_invite}
                            phx-value-notify_your_turn={!subscription.notify_your_turn}
                            phx-value-notify_game_result={subscription.notify_game_result}
                            phx-value-notify_chat_message={subscription.notify_chat_message}
                            class="rounded"
                          />
                          <span class="ml-2 text-sm text-gray-700">Your turn to play</span>
                        </label>

                        <label class="flex items-center">
                          <input
                            type="checkbox"
                            checked={subscription.notify_game_result}
                            phx-click="update_preferences"
                            phx-value-subscription_id={subscription.id}
                            phx-value-notify_game_invite={subscription.notify_game_invite}
                            phx-value-notify_your_turn={subscription.notify_your_turn}
                            phx-value-notify_game_result={!subscription.notify_game_result}
                            phx-value-notify_chat_message={subscription.notify_chat_message}
                            class="rounded"
                          />
                          <span class="ml-2 text-sm text-gray-700">Game results</span>
                        </label>

                        <label class="flex items-center">
                          <input
                            type="checkbox"
                            checked={subscription.notify_chat_message}
                            phx-click="update_preferences"
                            phx-value-subscription_id={subscription.id}
                            phx-value-notify_game_invite={subscription.notify_game_invite}
                            phx-value-notify_your_turn={subscription.notify_your_turn}
                            phx-value-notify_game_result={subscription.notify_game_result}
                            phx-value-notify_chat_message={!subscription.notify_chat_message}
                            class="rounded"
                          />
                          <span class="ml-2 text-sm text-gray-700">Chat messages</span>
                        </label>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp extract_device_info(nil), do: "Unknown Device"

  defp extract_device_info(user_agent) do
    cond do
      String.contains?(user_agent, "iPhone") -> "iPhone"
      String.contains?(user_agent, "iPad") -> "iPad"
      String.contains?(user_agent, "Android") -> "Android Device"
      String.contains?(user_agent, "Windows") -> "Windows PC"
      String.contains?(user_agent, "Macintosh") -> "Mac"
      String.contains?(user_agent, "Linux") -> "Linux PC"
      true -> "Unknown Device"
    end
  end
end
