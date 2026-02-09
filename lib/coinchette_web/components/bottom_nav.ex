defmodule CoinchetteWeb.BottomNav do
  @moduledoc """
  Bottom navigation bar for mobile PWA experience.
  Provides easy navigation between main sections of the app.
  """
  use CoinchetteWeb, :html

  attr :current_path, :string, required: true
  attr :class, :string, default: ""

  def bottom_nav(assigns) do
    ~H"""
    <nav class={[
      "fixed bottom-0 left-0 right-0 z-50",
      "bg-base-100 border-t border-base-300",
      "safe-area-inset-bottom",
      @class
    ]}>
      <div class="flex items-center justify-around h-16 max-w-lg mx-auto px-2">
        <!-- Home -->
        <.nav_item
          href={~p"/lobby"}
          icon="home"
          label="Accueil"
          active={@current_path == "/lobby"}
          testid="nav-home"
        />

        <!-- Friends -->
        <.nav_item
          href={~p"/friends"}
          icon="friends"
          label="Amis"
          active={@current_path == "/friends"}
          testid="nav-friends"
        />

        <!-- Profile -->
        <.nav_item
          href={~p"/profile"}
          icon="user"
          label="Profil"
          active={@current_path == "/profile"}
          testid="nav-profile"
        />
      </div>
    </nav>

    <!-- Spacer pour éviter que le contenu soit caché -->
    <div class="h-16"></div>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :testid, :string, default: nil

  defp nav_item(assigns) do
    ~H"""
    <.link
      navigate={@href}
      data-testid={@testid}
      class={[
        "flex flex-col items-center justify-center gap-1 px-3 py-2 rounded-lg transition-colors",
        @active && "text-primary bg-primary/10",
        !@active && "text-base-content/60 hover:text-base-content hover:bg-base-200"
      ]}
    >
      <.nav_icon name={@icon} class="w-6 h-6" />
      <span class="text-xs font-medium">{@label}</span>
    </.link>
    """
  end

  # Helper pour les icônes
  defp nav_icon(%{name: "home"} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"
      />
    </svg>
    """
  end

  defp nav_icon(%{name: "games"} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h7" />
    </svg>
    """
  end

  defp nav_icon(%{name: "friends"} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
      />
    </svg>
    """
  end

  defp nav_icon(%{name: "user"} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
      />
    </svg>
    """
  end
end
