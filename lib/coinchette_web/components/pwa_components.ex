defmodule CoinchettaWeb.PWAComponents do
  @moduledoc """
  PWA-related UI components for Progressive Web App functionality.
  """
  use Phoenix.Component

  @doc """
  Renders a PWA install banner/prompt.

  This component shows an install prompt to users who haven't installed the PWA yet.
  It appears at the top or bottom of the page and can be dismissed.

  ## Examples

      <.pwa_install_banner position="top" />
      <.pwa_install_banner position="bottom" dismissible={true} />

  """
  attr :position, :string, default: "top", values: ["top", "bottom"]
  attr :dismissible, :boolean, default: true
  attr :class, :string, default: ""

  def pwa_install_banner(assigns) do
    ~H"""
    <div
      id="pwa-install-banner"
      class={"#{position_class(@position)} #{@class} hidden"}
      phx-hook="PWAInstallBanner"
      role="banner"
      aria-live="polite"
    >
      <div class="container mx-auto px-4 py-3">
        <div class="flex items-center justify-between gap-4 bg-primary/10 border border-primary rounded-lg px-4 py-3">
          <div class="flex items-center gap-3 flex-1">
            <div class="hidden sm:block text-3xl">📱</div>
            <div class="flex-1">
              <p class="font-semibold text-sm sm:text-base">
                Installez Coinchette sur votre appareil
              </p>
              <p class="text-xs sm:text-sm text-base-content/70 mt-1">
                Accès rapide, notifications et expérience hors ligne
              </p>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <button
              type="button"
              phx-click="install-pwa"
              class="btn btn-primary btn-sm"
              aria-label="Installer l'application"
            >
              Installer
            </button>

            <%= if @dismissible do %>
              <button
                type="button"
                phx-click="dismiss-pwa-banner"
                class="btn btn-ghost btn-sm btn-circle"
                aria-label="Fermer"
              >
                ✕
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp position_class("top"), do: "fixed top-0 left-0 right-0 z-50"
  defp position_class("bottom"), do: "fixed bottom-0 left-0 right-0 z-50"
  defp position_class(_), do: "fixed top-0 left-0 right-0 z-50"

  @doc """
  Renders a PWA update notification banner.

  Shows when a new version of the app is available.

  ## Examples

      <.pwa_update_banner />

  """
  attr :class, :string, default: ""

  def pwa_update_banner(assigns) do
    ~H"""
    <div
      id="pwa-update-banner"
      class={"fixed top-0 left-0 right-0 z-50 #{@class} hidden"}
      role="alert"
      aria-live="assertive"
    >
      <div class="container mx-auto px-4 py-3">
        <div class="flex items-center justify-between gap-4 bg-info/10 border border-info rounded-lg px-4 py-3">
          <div class="flex items-center gap-3 flex-1">
            <div class="text-2xl">🔄</div>
            <div class="flex-1">
              <p class="font-semibold text-sm sm:text-base">
                Nouvelle version disponible !
              </p>
              <p class="text-xs sm:text-sm text-base-content/70 mt-1">
                Rechargez la page pour profiter des dernières améliorations
              </p>
            </div>
          </div>

          <button
            type="button"
            onclick="window.location.reload()"
            class="btn btn-info btn-sm"
            aria-label="Recharger la page"
          >
            Recharger
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a PWA offline indicator.

  Shows when the user is offline but the app still works.

  ## Examples

      <.pwa_offline_indicator />

  """
  attr :class, :string, default: ""

  def pwa_offline_indicator(assigns) do
    ~H"""
    <div
      id="pwa-offline-indicator"
      class={"fixed top-20 right-4 z-50 #{@class} hidden"}
      role="status"
      aria-live="polite"
    >
      <div class="alert alert-warning shadow-lg">
        <div class="flex items-center gap-2">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-6 w-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M18.364 5.636a9 9 0 010 12.728m0 0l-2.829-2.829m2.829 2.829L21 21M15.536 8.464a5 5 0 010 7.072m0 0l-2.829-2.829m-4.243 2.829a4.978 4.978 0 01-1.414-2.83m-1.414 5.658a9 9 0 01-2.167-9.238m7.824 2.167a1 1 0 111.414 1.414m-1.414-1.414L3 3m8.293 8.293l1.414 1.414"
            />
          </svg>
          <span class="text-sm">Mode hors ligne</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders PWA status information for debugging.

  Only shows in development environment.

  ## Examples

      <.pwa_debug_info />

  """
  def pwa_debug_info(assigns) do
    ~H"""
    <%= if Mix.env() == :dev do %>
      <div class="fixed bottom-4 left-4 z-50 text-xs bg-base-200 p-2 rounded shadow-lg opacity-50 hover:opacity-100 transition-opacity">
        <div class="font-mono space-y-1">
          <div id="pwa-sw-status">SW: <span class="text-warning">Checking...</span></div>
          <div id="pwa-install-status">Installé: <span class="text-warning">Checking...</span></div>
          <div id="pwa-online-status">En ligne: <span class="text-success">Oui</span></div>
        </div>
      </div>

      <script>
        // Check SW status
        if ('serviceWorker' in navigator) {
          navigator.serviceWorker.ready.then(() => {
            document.getElementById('pwa-sw-status').innerHTML =
              'SW: <span class="text-success">Actif</span>';
          });
        }

        // Check install status
        if (window.matchMedia('(display-mode: standalone)').matches ||
            window.navigator.standalone === true) {
          document.getElementById('pwa-install-status').innerHTML =
            'Installé: <span class="text-success">Oui</span>';
        } else {
          document.getElementById('pwa-install-status').innerHTML =
            'Installé: <span class="text-error">Non</span>';
        }

        // Check online status
        window.addEventListener('online', () => {
          document.getElementById('pwa-online-status').innerHTML =
            'En ligne: <span class="text-success">Oui</span>';
        });

        window.addEventListener('offline', () => {
          document.getElementById('pwa-online-status').innerHTML =
            'En ligne: <span class="text-error">Non</span>';
        });
      </script>
    <% end %>
    """
  end
end
