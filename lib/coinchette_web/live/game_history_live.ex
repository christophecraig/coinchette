defmodule CoinchetteWeb.GameHistoryLive do
  use CoinchetteWeb, :live_view

  alias Coinchette.Multiplayer

  on_mount {CoinchetteWeb.Auth, :ensure_authenticated}

  def mount(%{"id" => game_id}, _session, socket) do
    game = Multiplayer.get_game!(game_id)

    socket =
      socket
      |> assign(:page_title, "Game History - #{game.room_code}")
      |> assign(:game, game)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
      <.header>
        Game History
        <:subtitle>Room Code: <%= @game.room_code %></:subtitle>
      </.header>

      <div class="mt-8 bg-base-200 rounded-box p-8">
        <p class="text-base-content/60">Game history details will be implemented in Phase 7</p>

        <div class="mt-6">
          <dl class="space-y-2">
            <div>
              <dt class="text-sm text-base-content/60">Status</dt>
              <dd class="font-semibold"><%= @game.status %></dd>
            </div>
            <%= if @game.winner_team do %>
              <div>
                <dt class="text-sm text-base-content/60">Winner</dt>
                <dd class="font-semibold">Team <%= @game.winner_team %></dd>
              </div>
            <% end %>
            <%= if @game.scores do %>
              <div>
                <dt class="text-sm text-base-content/60">Final Score</dt>
                <dd class="font-semibold">
                  Team 0: <%= Map.get(@game.scores, "0", 0) %> - Team 1: <%= Map.get(@game.scores, "1", 0) %>
                </dd>
              </div>
            <% end %>
          </dl>
        </div>

        <div class="mt-6">
          <.link navigate="/lobby" class="btn btn-ghost">
            Back to Lobby
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
