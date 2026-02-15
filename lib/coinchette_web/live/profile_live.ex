defmodule CoinchetteWeb.ProfileLive do
  use CoinchetteWeb, :live_view

  alias Coinchette.{Accounts, Multiplayer}
  alias Coinchette.Accounts.UserStats

  on_mount {CoinchetteWeb.Auth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    {:ok, stats} = Accounts.get_or_create_stats(user.id)
    recent_games = Multiplayer.list_recent_finished_games(user.id, 10)

    socket =
      socket
      |> assign(:page_title, "Profile - #{user.username}")
      |> assign(:user, user)
      |> assign(:stats, stats)
      |> assign(:recent_games, recent_games)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 p-4 sm:p-8">
      <div class="max-w-6xl mx-auto">
        <!-- Header -->
        <div class="mb-6">
          <div class="flex items-center justify-between mb-4">
            <.link navigate="/lobby" class="btn btn-ghost btn-sm">
              ← Retour au lobby
            </.link>
            <div class="flex gap-2">
              <.link navigate="/leaderboard" class="btn btn-ghost btn-sm gap-2">
                <span class="text-lg">🏆</span>
                <span class="hidden sm:inline">Classement</span>
              </.link>
              <.link navigate="/settings/notifications" class="btn btn-ghost btn-sm gap-2">
                <span class="text-lg">🔔</span>
                <span class="hidden sm:inline">Notifications</span>
              </.link>
            </div>
          </div>
          <h1 class="text-3xl sm:text-4xl font-bold text-base-content" data-testid="profile-username">
            Profil de {@user.username}
          </h1>
        </div>

        <!-- ELO Card -->
        <div class="card bg-base-100 shadow-xl mb-8" data-testid="elo-card">
          <div class="card-body flex-row items-center justify-between">
            <div>
              <p class="text-sm text-base-content/60">Score ELO</p>
              <p class={["text-5xl font-bold font-mono", UserStats.elo_color(@stats.elo_rating)]}>
                {@stats.elo_rating}
              </p>
              <p class={["text-sm font-semibold mt-1", UserStats.elo_color(@stats.elo_rating)]}>
                {UserStats.elo_rank(@stats.elo_rating)}
              </p>
            </div>
            <div class="text-6xl opacity-80">
              <%= case UserStats.elo_rank(@stats.elo_rating) do %>
                <% "Débutant" -> %>🌱
                <% "Apprenti" -> %>📘
                <% "Joueur" -> %>🃏
                <% "Confirmé" -> %>⚔️
                <% "Expert" -> %>🔥
                <% "Maître" -> %>👑
              <% end %>
            </div>
          </div>
        </div>

        <!-- Stats Overview Cards -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8" data-testid="stats-cards">
          <.stat_card
            title="Parties jouées"
            value={@stats.games_played}
            icon="🎮"
            color="bg-blue-500"
          />
          <.stat_card
            title="Victoires"
            value={@stats.games_won}
            icon="🏆"
            color="bg-green-500"
            subtitle={"#{UserStats.win_rate(@stats)}% de victoires"}
          />
          <.stat_card
            title="Défaites"
            value={@stats.games_lost}
            icon="😔"
            color="bg-red-500"
          />
          <.stat_card
            title="Meilleur score"
            value={@stats.best_score}
            icon="⭐"
            color="bg-yellow-500"
            subtitle="points"
          />
        </div>

        <!-- Streaks + Team Stats -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <!-- Streaks -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">🔥 Séries de victoires</h2>
              <div class="grid grid-cols-2 gap-4 mt-4">
                <div class="text-center p-4 bg-base-200 rounded-xl">
                  <p class="text-sm text-base-content/60">Série actuelle</p>
                  <p class="text-3xl font-bold text-success">{@stats.current_win_streak}</p>
                </div>
                <div class="text-center p-4 bg-base-200 rounded-xl">
                  <p class="text-sm text-base-content/60">Meilleure série</p>
                  <p class="text-3xl font-bold text-warning">{@stats.best_win_streak}</p>
                </div>
              </div>
            </div>
          </div>

          <!-- Team Performance -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">📊 Performance par équipe</h2>
              <div class="space-y-4 mt-4">
                <div>
                  <div class="flex justify-between text-sm mb-1">
                    <span>Équipe 1 (positions 1-3)</span>
                    <span class="font-bold">
                      {UserStats.team_win_rate(@stats, 0, @stats.games_as_team0)}% victoires
                    </span>
                  </div>
                  <progress
                    class="progress progress-success w-full"
                    value={UserStats.team_win_rate(@stats, 0, @stats.games_as_team0)}
                    max="100"
                  />
                  <p class="text-xs text-base-content/60 mt-1">
                    {@stats.wins_as_team0}/{@stats.games_as_team0} parties
                  </p>
                </div>
                <div>
                  <div class="flex justify-between text-sm mb-1">
                    <span>Équipe 2 (positions 2-4)</span>
                    <span class="font-bold">
                      {UserStats.team_win_rate(@stats, 1, @stats.games_as_team1)}% victoires
                    </span>
                  </div>
                  <progress
                    class="progress progress-info w-full"
                    value={UserStats.team_win_rate(@stats, 1, @stats.games_as_team1)}
                    max="100"
                  />
                  <p class="text-xs text-base-content/60 mt-1">
                    {@stats.wins_as_team1}/{@stats.games_as_team1} parties
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Points + Achievements -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <!-- Points Statistics -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">📊 Statistiques de points</h2>

              <div class="space-y-4 mt-4">
                <div>
                  <div class="flex justify-between text-sm mb-1">
                    <span>Points marqués (total)</span>
                    <span class="font-bold">{@stats.total_points_scored}</span>
                  </div>
                  <div class="flex justify-between text-sm text-base-content/60">
                    <span>Moyenne par partie</span>
                    <span>{UserStats.average_points_scored(@stats)}</span>
                  </div>
                </div>

                <div class="divider"></div>

                <div>
                  <div class="flex justify-between text-sm mb-1">
                    <span>Points encaissés (total)</span>
                    <span class="font-bold">{@stats.total_points_conceded}</span>
                  </div>
                  <div class="flex justify-between text-sm text-base-content/60">
                    <span>Moyenne par partie</span>
                    <span>{UserStats.average_points_conceded(@stats)}</span>
                  </div>
                </div>

                <div class="divider"></div>

                <div>
                  <div class="flex justify-between text-sm">
                    <span>Différentiel</span>
                    <span class={[
                      "font-bold",
                      @stats.total_points_scored - @stats.total_points_conceded >= 0 &&
                        "text-success",
                      @stats.total_points_scored - @stats.total_points_conceded < 0 && "text-error"
                    ]}>
                      {if @stats.total_points_scored - @stats.total_points_conceded >= 0,
                        do: "+",
                        else: ""}{@stats.total_points_scored - @stats.total_points_conceded}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Achievements -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">🎖️ Accomplissements</h2>

              <div class="space-y-4 mt-4">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <span class="text-3xl">👑</span>
                    <div>
                      <div class="font-semibold">Belote/Rebelote</div>
                      <div class="text-sm text-base-content/60">
                        Annoncées {@stats.belote_rebelote_count} fois
                      </div>
                    </div>
                  </div>
                  <div class="badge badge-lg badge-primary">
                    {@stats.belote_rebelote_count}
                  </div>
                </div>

                <div class="divider"></div>

                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <span class="text-3xl">🔥</span>
                    <div>
                      <div class="font-semibold">Ratio victoires</div>
                      <div class="text-sm text-base-content/60">
                        Pourcentage de réussite
                      </div>
                    </div>
                  </div>
                  <div class="badge badge-lg badge-success">
                    {UserStats.win_rate(@stats)}%
                  </div>
                </div>

                <%= if @stats.games_played >= 10 do %>
                  <div class="divider"></div>

                  <div class="flex items-center justify-between">
                    <div class="flex items-center gap-3">
                      <span class="text-3xl">💪</span>
                      <div>
                        <div class="font-semibold">Joueur expérimenté</div>
                        <div class="text-sm text-base-content/60">
                          Plus de 10 parties jouées
                        </div>
                      </div>
                    </div>
                    <div class="badge badge-lg badge-secondary">
                      ✓
                    </div>
                  </div>
                <% end %>

                <%= if UserStats.win_rate(@stats) >= 60.0 and @stats.games_played >= 5 do %>
                  <div class="divider"></div>

                  <div class="flex items-center justify-between">
                    <div class="flex items-center gap-3">
                      <span class="text-3xl">🌟</span>
                      <div>
                        <div class="font-semibold">Expert</div>
                        <div class="text-sm text-base-content/60">
                          Plus de 60% de victoires
                        </div>
                      </div>
                    </div>
                    <div class="badge badge-lg badge-warning">
                      ✓
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <!-- Recent Games -->
        <div class="card bg-base-100 shadow-xl" data-testid="recent-games">
          <div class="card-body">
            <h2 class="card-title">📜 Historique récent</h2>

            <%= if Enum.empty?(@recent_games) do %>
              <div class="text-center py-8 text-base-content/60">
                <p>Aucune partie terminée pour le moment.</p>
                <.link navigate="/lobby" class="btn btn-primary mt-4">
                  Commencer à jouer
                </.link>
              </div>
            <% else %>
              <div class="overflow-x-auto mt-4">
                <table class="table table-zebra">
                  <thead>
                    <tr>
                      <th>Date</th>
                      <th>Résultat</th>
                      <th>Score</th>
                      <th>Joueurs</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for game <- @recent_games do %>
                      <.game_row game={game} user={@user} />
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body p-4">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-xs sm:text-sm text-base-content/60">{@title}</p>
            <p class="text-2xl sm:text-3xl font-bold">{@value}</p>
            <%= if assigns[:subtitle] do %>
              <p class="text-xs text-base-content/60 mt-1">{@subtitle}</p>
            <% end %>
          </div>
          <div class={["text-3xl sm:text-4xl", @color, "rounded-full w-12 h-12 sm:w-16 sm:h-16 flex items-center justify-center"]}>
            {@icon}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp game_row(assigns) do
    user_position = get_user_position(assigns.game, assigns.user.id)
    user_team = if user_position, do: rem(user_position, 2), else: nil
    winner_team = assigns.game.winner_team
    did_win = user_team == winner_team

    assigns = assign(assigns, :did_win, did_win)

    ~H"""
    <tr>
      <td>
        <div class="text-sm">
          {format_date(@game.finished_at)}
        </div>
      </td>
      <td>
        <%= if @did_win do %>
          <span class="badge badge-success">Victoire</span>
        <% else %>
          <span class="badge badge-error">Défaite</span>
        <% end %>
      </td>
      <td>
        <div class="text-sm font-mono">
          <%= if @game.scores do %>
            {Map.get(@game.scores, "0", 0)} - {Map.get(@game.scores, "1", 0)}
          <% else %>
            N/A
          <% end %>
        </div>
      </td>
      <td>
        <div class="text-sm">
          {length(@game.game_players)} joueurs
        </div>
      </td>
      <td>
        <.link navigate={~p"/game/#{@game.id}/history"} class="btn btn-ghost btn-sm">
          Détails
        </.link>
      </td>
    </tr>
    """
  end

  defp get_user_position(game, user_id) do
    game.game_players
    |> Enum.find(fn player -> player.user_id == user_id end)
    |> case do
      nil -> nil
      player -> player.position
    end
  end

  defp format_date(nil), do: "N/A"

  defp format_date(datetime) do
    datetime
    |> NaiveDateTime.to_date()
    |> Calendar.strftime("%d/%m/%Y")
  end
end
