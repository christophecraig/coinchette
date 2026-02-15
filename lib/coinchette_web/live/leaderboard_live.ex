defmodule CoinchetteWeb.LeaderboardLive do
  use CoinchetteWeb, :live_view

  alias Coinchette.{Friends, Accounts}
  alias Coinchette.Accounts.UserStats

  on_mount {CoinchetteWeb.Auth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    {:ok, my_stats} = Accounts.get_or_create_stats(user.id)
    friends = Friends.list_friends_with_stats(user.id)

    # Insert current user into the list
    me = %{
      friend_id: user.id,
      username: user.username,
      elo_rating: my_stats.elo_rating,
      games_played: my_stats.games_played,
      games_won: my_stats.games_won
    }

    entries =
      [me | friends]
      |> Enum.sort_by(& &1.elo_rating, :desc)
      |> Enum.with_index(1)

    socket =
      socket
      |> assign(:page_title, "Classement")
      |> assign(:user, user)
      |> assign(:entries, entries)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 p-4 sm:p-8">
      <div class="max-w-2xl mx-auto">
        <div class="mb-6">
          <.link navigate="/profile" class="btn btn-ghost btn-sm">
            ← Retour au profil
          </.link>
          <h1 class="text-3xl font-bold text-base-content mt-2">Classement amis</h1>
          <p class="text-base-content/60 text-sm mt-1">Classé par score ELO</p>
        </div>

        <%= if @entries == [] do %>
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body text-center py-12">
              <p class="text-base-content/60">Ajoutez des amis pour voir le classement !</p>
              <.link navigate="/friends" class="btn btn-primary mt-4">
                Trouver des amis
              </.link>
            </div>
          </div>
        <% else %>
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body p-0">
              <div class="overflow-x-auto">
                <table class="table">
                  <thead>
                    <tr>
                      <th class="w-12">#</th>
                      <th>Joueur</th>
                      <th class="text-center">ELO</th>
                      <th class="text-center hidden sm:table-cell">Parties</th>
                      <th class="text-center hidden sm:table-cell">Victoires %</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for {entry, rank} <- @entries do %>
                      <tr class={entry.friend_id == @user.id && "bg-primary/10 font-semibold"}>
                        <td>
                          <.rank_badge rank={rank} />
                        </td>
                        <td>
                          <div class="flex items-center gap-2">
                            <span>{entry.username}</span>
                            <%= if entry.friend_id == @user.id do %>
                              <span class="badge badge-xs badge-primary">Vous</span>
                            <% end %>
                          </div>
                        </td>
                        <td class="text-center">
                          <span class={["font-mono font-bold", UserStats.elo_color(entry.elo_rating)]}>
                            {entry.elo_rating}
                          </span>
                        </td>
                        <td class="text-center hidden sm:table-cell">
                          {entry.games_played}
                        </td>
                        <td class="text-center hidden sm:table-cell">
                          {if entry.games_played > 0, do: Float.round(entry.games_won / entry.games_played * 100, 1), else: 0.0}%
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp rank_badge(%{rank: 1} = assigns) do
    ~H"""
    <span class="text-xl">🥇</span>
    """
  end

  defp rank_badge(%{rank: 2} = assigns) do
    ~H"""
    <span class="text-xl">🥈</span>
    """
  end

  defp rank_badge(%{rank: 3} = assigns) do
    ~H"""
    <span class="text-xl">🥉</span>
    """
  end

  defp rank_badge(assigns) do
    ~H"""
    <span class="text-base-content/60">{@rank}</span>
    """
  end
end
