defmodule CoinchetteWeb.LobbyLive do
  use CoinchetteWeb, :live_view

  on_mount {CoinchetteWeb.Auth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Lobby")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl">
      <.header>
        Game Lobby
        <:subtitle>Welcome, <%= @current_user.username %>!</:subtitle>
      </.header>

      <div class="mt-8">
        <p class="text-gray-600">Multiplayer features coming soon...</p>
        <div class="mt-4">
          <.link navigate="/game" class="text-brand hover:underline">
            Play Solo Game
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
