defmodule CoinchetteWeb.GameLive do
  use CoinchetteWeb, :live_view

  alias Coinchette.Games.{Game, Card}
  alias Coinchette.Bots

  @impl true
  def mount(_params, _session, socket) do
    # Créer une nouvelle partie avec enchères
    game =
      Game.new(dealer_position: 0)
      |> Game.deal_initial_cards()

    {:ok,
     socket
     |> assign(:game, game)
     |> assign(:selected_card, nil)
     |> assign(:message, "Phase d'enchères - À vous de jouer")
     |> assign(:belote_announcement, nil)}
  end

  @impl true
  def handle_event("play_card", %{"card" => card_id}, socket) do
    [rank_str, suit_str] = String.split(card_id, "_")
    rank = String.to_existing_atom(rank_str)
    suit = String.to_existing_atom(suit_str)
    card = Card.new(rank, suit)

    game = socket.assigns.game
    current_player = Game.current_player(game)

    # Joueur humain est toujours position 0
    if current_player.position == 0 do
      case Game.play_card(game, card) do
        {:ok, updated_game} ->
          # Détecter annonce Belote/Rebelote
          announcement = detect_belote_announcement(game, updated_game)

          # Après le coup du joueur, faire jouer les bots
          final_game = play_bot_turns(updated_game)

          {:noreply,
           socket
           |> assign(:game, final_game)
           |> assign(:message, get_game_message(final_game))
           |> assign(:belote_announcement, announcement)}

        {:error, :invalid_card} ->
          {:noreply,
           socket
           |> put_flash(:error, "Carte invalide selon les règles FFB")
           |> assign(:message, "Carte invalide ! Choisissez-en une autre.")}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Erreur: #{inspect(reason)}")
           |> assign(:message, "Erreur lors du coup.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("new_game", _params, socket) do
    new_game =
      Game.new(dealer_position: 0)
      |> Game.deal_initial_cards()

    {:noreply,
     socket
     |> assign(:game, new_game)
     |> assign(:message, "Nouvelle partie commencée !")
     |> assign(:belote_announcement, nil)
     |> clear_flash()}
  end

  @impl true
  def handle_event("bid_take", _params, socket) do
    game = socket.assigns.game

    case Game.make_bid(game, :take) do
      {:ok, updated_game} ->
        # Enchères terminées, distribuer les cartes finales
        game_with_announcements = Game.complete_deal(updated_game)
        # Compléter phase annonces et démarrer
        final_game = Game.complete_announcements(game_with_announcements)
        # Faire jouer les bots si nécessaire
        final_game = play_bot_turns(final_game)

        {:noreply,
         socket
         |> assign(:game, final_game)
         |> assign(:message, get_game_message(final_game))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Erreur: #{inspect(reason)}")
         |> assign(:message, "Erreur lors de l'enchère.")}
    end
  end

  @impl true
  def handle_event("bid_pass", _params, socket) do
    game = socket.assigns.game

    case Game.make_bid(game, :pass) do
      {:ok, updated_game} ->
        # Faire jouer les bots pour les enchères
        final_game = play_bidding_bots(updated_game)

        message =
          cond do
            final_game.status == :bidding_failed ->
              "Tous ont passé ! Redistribution..."

            final_game.status == :bidding_completed ->
              "Enchères terminées, distribution finale..."

            true ->
              get_bidding_message(final_game)
          end

        # Si enchères terminées, distribuer et jouer
        final_game =
          if final_game.status == :bidding_completed do
            game_after_deal = Game.complete_deal(final_game)
            play_bot_turns(game_after_deal)
          else
            final_game
          end

        {:noreply,
         socket
         |> assign(:game, final_game)
         |> assign(:message, message)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Erreur: #{inspect(reason)}")
         |> assign(:message, "Erreur lors de l'enchère.")}
    end
  end

  @impl true
  def handle_event("bid_choose", %{"suit" => suit_str}, socket) do
    game = socket.assigns.game
    suit = String.to_existing_atom(suit_str)

    case Game.make_bid(game, {:choose, suit}) do
      {:ok, updated_game} ->
        # Enchères terminées, distribuer les cartes finales et démarrer
        final_game = Game.complete_deal(updated_game)
        # Faire jouer les bots si nécessaire
        final_game = play_bot_turns(final_game)

        {:noreply,
         socket
         |> assign(:game, final_game)
         |> assign(:message, get_game_message(final_game))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Erreur: #{inspect(reason)}")
         |> assign(:message, "Erreur lors de l'enchère.")}
    end
  end

  # Détecte si une annonce Belote/Rebelote a été faite
  defp detect_belote_announcement(old_game, new_game) do
    cond do
      # Rebelote : belote_rebelote vient d'être set
      new_game.belote_rebelote != nil and old_game.belote_rebelote == nil ->
        {team, _} = new_game.belote_rebelote
        {:rebelote, team}

      # Belote : belote_announced vient d'être set
      new_game.belote_announced != nil and old_game.belote_announced == nil ->
        {player_position, _} = new_game.belote_announced
        player = Enum.at(new_game.players, player_position)
        {:belote, player.team}

      true ->
        nil
    end
  end

  # Joue les tours des bots jusqu'à ce que ce soit au tour du joueur humain
  defp play_bot_turns(game) do
    current_player = Game.current_player(game)

    cond do
      # Partie terminée
      Game.game_over?(game) ->
        game

      # Tour du joueur humain (position 0)
      current_player.position == 0 ->
        game

      # Tour d'un bot
      true ->
        case Game.play_bot_turn(game, Bots.Basic) do
          {:ok, updated_game} ->
            # Continue récursivement
            # Petite pause pour animation
            Process.sleep(500)
            play_bot_turns(updated_game)

          {:error, _reason} ->
            game
        end
    end
  end

  # Fait enchérir les bots jusqu'au tour du joueur humain
  defp play_bidding_bots(game) do
    if game.status != :bidding do
      game
    else
      current_bidder = game.bidding.current_bidder

      cond do
        # Tour du joueur humain (position 1, car donneur = 0)
        current_bidder == 1 ->
          game

        # Tour d'un bot
        true ->
          # Stratégie simple : bot prend toujours au premier tour s'il peut
          # Sinon passe
          action =
            if game.bidding.round == 1 do
              # Au premier tour : 50% chance de prendre
              if :rand.uniform() > 0.5, do: :take, else: :pass
            else
              # Au second tour : choisir une couleur aléatoire
              if :rand.uniform() > 0.5 do
                suits = [:spades, :hearts, :diamonds, :clubs]
                available_suits = Enum.reject(suits, &(&1 == game.bidding.proposed_trump))
                {:choose, Enum.random(available_suits)}
              else
                :pass
              end
            end

          case Game.make_bid(game, action) do
            {:ok, updated_game} ->
              # Pause pour simulation
              Process.sleep(800)
              play_bidding_bots(updated_game)

            {:error, _reason} ->
              game
          end
      end
    end
  end

  defp get_bidding_message(game) do
    if game.bidding.current_bidder == 1 do
      round_text = if game.bidding.round == 1, do: "Premier", else: "Second"
      "#{round_text} tour d'enchères - À vous de jouer"
    else
      "Le bot enchérit..."
    end
  end

  defp get_game_message(game) do
    cond do
      game.status == :bidding ->
        get_bidding_message(game)

      game.status == :bidding_failed ->
        "Tous ont passé ! Redistribution nécessaire"

      Game.game_over?(game) ->
        winner_team = Game.winner(game)
        loser_team = if winner_team == 0, do: 1, else: 0
        winner_score = game.scores[winner_team]
        loser_score = game.scores[loser_team]

        if winner_team == 0 do
          "🎉 Victoire ! Vous gagnez #{winner_score} - #{loser_score}"
        else
          "😢 Défaite... Score final: #{game.scores[0]} - #{game.scores[1]}"
        end

      Game.current_player(game).position == 0 ->
        "Votre tour de jouer"

      true ->
        "Le bot joue..."
    end
  end

  # Vérifie si une carte est jouable par le joueur humain
  def card_playable?(game, card) do
    current_player = Game.current_player(game)

    if current_player.position == 0 do
      alias Coinchette.Games.Rules

      valid_cards =
        Rules.valid_cards(
          current_player,
          game.current_trick,
          game.trump_suit,
          current_player.position
        )

      card in valid_cards
    else
      false
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-800 to-green-600 p-4 sm:p-6 lg:p-8">
      <div class="max-w-6xl mx-auto">
        <!-- Header -->
        <div class="relative mb-4 sm:mb-6 lg:mb-8">
          <!-- Theme toggle (top right) -->
          <div class="absolute top-0 right-0 z-10">
            <Layouts.theme_toggle />
          </div>

          <div class="text-center">
            <h1 class="text-2xl sm:text-3xl lg:text-4xl font-bold text-white mb-2">🃏 Coinchette</h1>
            <p class="text-green-100 text-sm sm:text-base lg:text-lg">{@message}</p>
            <div class="mt-3 sm:mt-4">
              <button
                phx-click="new_game"
                class="btn btn-primary w-full sm:w-auto"
                data-testid="new-game-button"
              >
                Nouvelle Partie
              </button>
            </div>
          </div>
        </div>

    <!-- Game Info Header - Always Visible -->
        <%= if @game.status != :bidding do %>
          <.game_info_header game={@game} />
        <% end %>

    <!-- Notification Belote/Rebelote -->
        <%= if @belote_announcement do %>
          <.belote_notification announcement={@belote_announcement} />
        <% end %>

    <!-- Notification Annonces -->
        <%= if @game.announcements_result && @game.announcements_result.total_points > 0 && length(@game.tricks_won) <= 1 do %>
          <.announcements_notification result={@game.announcements_result} />
        <% end %>

        <%= if @game.status == :bidding do %>
          <!-- Interface d'enchères -->
          <.bidding_interface game={@game} />
        <% else %>
          <!-- Plateau de jeu normal -->
          <.game_board game={@game} />
        <% end %>

    <!-- Score final (only at game end) -->
        <%= if Game.game_over?(@game) do %>
          <.score_panel game={@game} />
        <% end %>
      </div>
    </div>
    """
  end

  # Composant notification Belote/Rebelote
  defp belote_notification(assigns) do
    ~H"""
    <div class="alert alert-success shadow-lg mb-4 animate-pulse">
      <div class="flex items-center gap-2">
        <%= case @announcement do %>
          <% {:belote, team} -> %>
            <span class="text-2xl">👑</span>
            <div>
              <h3 class="font-bold text-lg">Belote !</h3>
              <div class="text-sm">
                <%= if team == 0 do %>
                  Annoncée par votre équipe
                <% else %>
                  Annoncée par l'équipe adverse
                <% end %>
              </div>
            </div>
          <% {:rebelote, team} -> %>
            <span class="text-2xl">👸</span>
            <div>
              <h3 class="font-bold text-lg">Rebelote !</h3>
              <div class="text-sm">
                <%= if team == 0 do %>
                  Votre équipe gagne +20 points
                <% else %>
                  L'équipe adverse gagne +20 points
                <% end %>
              </div>
            </div>
          <% _ -> %>
        <% end %>
      </div>
    </div>
    """
  end

  # Composant notification Annonces
  defp announcements_notification(assigns) do
    ~H"""
    <div class="alert alert-info shadow-lg mb-4">
      <div class="flex items-center gap-2">
        <span class="text-2xl">🎺</span>
        <div>
          <h3 class="font-bold text-lg">Annonces détectées !</h3>
          <div class="text-sm">
            <%= if @result.winning_team == 0 do %>
              Votre équipe gagne +{@result.total_points} points
            <% else %>
              L'équipe adverse gagne +{@result.total_points} points
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Composant interface d'enchères
  defp bidding_interface(assigns) do
    ~H"""
    <div class="relative bg-green-700 rounded-3xl shadow-2xl p-12 min-h-[600px]">
      <div class="flex flex-col items-center justify-center h-full space-y-8">
        <!-- Carte retournée -->
        <div class="text-center">
          <h2 class="text-2xl font-bold text-white mb-4">Carte retournée</h2>
          <div class="flex justify-center">
            <.card_component card={@game.proposed_trump_card} clickable={false} enlarged={true} />
          </div>
          <p class="text-white mt-4 text-lg">
            Couleur proposée :
            <span class="font-bold">{format_suit(@game.proposed_trump_card.suit)}</span>
          </p>
        </div>
        
    <!-- Boutons d'enchères -->
        <%= if @game.bidding.current_bidder == 1 do %>
          <div class="card bg-base-100 shadow-xl max-w-md">
            <div class="card-body">
              <h3 class="card-title">Votre enchère</h3>

              <%= if @game.bidding.round == 1 do %>
                <!-- Premier tour : Prendre ou Passer -->
                <p class="text-sm text-base-content/70 mb-4">
                  Premier tour - Voulez-vous prendre {format_suit(@game.proposed_trump_card.suit)} comme atout ?
                </p>
                <div class="flex gap-4">
                  <button
                    phx-click="bid_take"
                    class="btn btn-success flex-1"
                    data-testid="bid-take-button"
                  >
                    ✅ Je prends
                  </button>
                  <button
                    phx-click="bid_pass"
                    class="btn btn-ghost flex-1"
                    data-testid="bid-pass-button"
                  >
                    ⏭️ Je passe
                  </button>
                </div>
              <% else %>
                <!-- Second tour : Choisir couleur ou Passer -->
                <p class="text-sm text-base-content/70 mb-4">
                  Second tour - Choisissez une autre couleur ou passez
                </p>
                <div class="grid grid-cols-2 gap-3 mb-4">
                  <%= for suit <- [:spades, :hearts, :diamonds, :clubs] do %>
                    <%= if suit != @game.proposed_trump_card.suit do %>
                      <button
                        phx-click="bid_choose"
                        phx-value-suit={suit}
                        class="btn btn-outline btn-lg"
                      >
                        {format_suit(suit)}
                      </button>
                    <% end %>
                  <% end %>
                </div>
                <button
                  phx-click="bid_pass"
                  class="btn btn-ghost w-full"
                >
                  ⏭️ Je passe
                </button>
              <% end %>
            </div>
          </div>
        <% else %>
          <div class="alert alert-info">
            <span>Le bot enchérit...</span>
          </div>
        <% end %>
        
    <!-- Info enchères -->
        <div class="text-white text-sm space-y-1">
          <p><strong>Tour :</strong> {@game.bidding.round} / 2</p>
          <p><strong>Enchérisseur actuel :</strong> Joueur {@game.bidding.current_bidder + 1}</p>
        </div>
      </div>
    </div>
    """
  end

  # Composant plateau de jeu normal
  # Game Info Header - Scores and Trump (always visible during play)
  defp game_info_header(assigns) do
    ~H"""
    <div class="bg-white/10 backdrop-blur-sm rounded-lg p-4 mb-4">
      <div class="grid grid-cols-3 gap-4 items-center">
        <!-- Team 0 Score -->
        <div class="text-left">
          <div class="text-xs text-white/70 mb-1">Équipe 1 (Vous + Marcel)</div>
          <div class="flex items-center gap-2">
            <span class="text-3xl font-bold text-white">{@game.scores[0]}</span>
            <span class="text-sm text-white/60">pts</span>
            <%= if @game.belote_rebelote && elem(@game.belote_rebelote, 0) == 0 do %>
              <span class="badge badge-success badge-sm">👑 +20</span>
            <% end %>
          </div>
          <div class="text-xs text-white/50">
            {@game.tricks_won |> Enum.count(fn {team, _} -> team == 0 end)} plis
          </div>
        </div>
        <!-- Trump Info (center) -->
        <div class="text-center">
          <div class="text-xs text-white/70 mb-1">Atout</div>
          <div class="text-6xl">{format_suit(@game.trump_suit)}</div>
          <div class="text-xs text-white/70 mt-1">
            Pli {length(@game.tricks_won) + 1}/8
          </div>
        </div>
        <!-- Team 1 Score -->
        <div class="text-right">
          <div class="text-xs text-white/70 mb-1">Équipe 2 (Josette + René)</div>
          <div class="flex items-center gap-2 justify-end">
            <span class="text-3xl font-bold text-white">{@game.scores[1]}</span>
            <span class="text-sm text-white/60">pts</span>
            <%= if @game.belote_rebelote && elem(@game.belote_rebelote, 0) == 1 do %>
              <span class="badge badge-success badge-sm">👑 +20</span>
            <% end %>
          </div>
          <div class="text-xs text-white/50">
            {@game.tricks_won |> Enum.count(fn {team, _} -> team == 1 end)} plis
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp game_board(assigns) do
    ~H"""
    <div class="relative bg-green-700 rounded-3xl shadow-2xl p-12 min-h-[500px]" data-testid="game-board">
        <!-- Joueur Nord (Bot 2) -->
        <div class="absolute top-4 left-1/2 transform -translate-x-1/2">
          <.player_hand
            player={Enum.at(@game.players, 2)}
            position="north"
            current={Game.current_player(@game).position == 2}
          />
        </div>

      <!-- Joueur Ouest (Bot 3) -->
        <div class="absolute left-4 top-1/2 transform -translate-y-1/2">
          <.player_hand
            player={Enum.at(@game.players, 3)}
            position="west"
            current={Game.current_player(@game).position == 3}
          />
        </div>

      <!-- Joueur Est (Bot 1) -->
        <div class="absolute right-4 top-1/2 transform -translate-y-1/2">
          <.player_hand
            player={Enum.at(@game.players, 1)}
            position="east"
            current={Game.current_player(@game).position == 1}
          />
        </div>

      <!-- Pli en cours (centre) -->
        <div class="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2">
          <.current_trick trick={@game.current_trick} trump_suit={@game.trump_suit} />
        </div>

      <!-- Joueur Sud (Humain) -->
        <div class="absolute bottom-4 left-1/2 transform -translate-x-1/2">
          <.player_hand
            player={Enum.at(@game.players, 0)}
            position="south"
            current={Game.current_player(@game).position == 0}
            playable={true}
            game={@game}
          />
        </div>
    </div>
    """
  end

  # Composant panneau de score (simplified - main scores are in header)
  defp score_panel(assigns) do
    ~H"""
    <%= if Game.game_over?(@game) do %>
      <div class="mt-8" data-testid="score-panel">
        <div class="alert alert-success shadow-lg">
          <div class="w-full">
            <h2 class="font-bold text-xl mb-2">🎉 Partie terminée !</h2>

            <div class="grid grid-cols-2 gap-4 mb-4">
              <div class="text-left">
                <div class="text-lg font-semibold">Équipe 1 (Vous + Marcel)</div>
                <div class="flex items-center gap-2 mt-1">
                  <span class="text-3xl font-bold">{@game.scores[0]}</span>
                  <span>points</span>
                  <%= if @game.belote_rebelote && elem(@game.belote_rebelote, 0) == 0 do %>
                    <span class="badge badge-sm">👑 +20</span>
                  <% end %>
                  <%= if @game.announcements_result && @game.announcements_result.winning_team == 0 && @game.announcements_result.total_points > 0 do %>
                    <span class="badge badge-sm">🎺 +{@game.announcements_result.total_points}</span>
                  <% end %>
                </div>
              </div>

              <div class="text-right">
                <div class="text-lg font-semibold">Équipe 2 (Josette + René)</div>
                <div class="flex items-center gap-2 justify-end mt-1">
                  <span class="text-3xl font-bold">{@game.scores[1]}</span>
                  <span>points</span>
                  <%= if @game.belote_rebelote && elem(@game.belote_rebelote, 0) == 1 do %>
                    <span class="badge badge-sm">👑 +20</span>
                  <% end %>
                  <%= if @game.announcements_result && @game.announcements_result.winning_team == 1 && @game.announcements_result.total_points > 0 do %>
                    <span class="badge badge-sm">🎺 +{@game.announcements_result.total_points}</span>
                  <% end %>
                </div>
              </div>
            </div>

            <div class="divider"></div>

            <div class="text-center">
              <span class="text-2xl font-bold">
                <%= if Game.winner(@game) == 0 do %>
                  🎉 Victoire !
                <% else %>
                  😢 Défaite
                <% end %>
              </span>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # Composant main de joueur
  defp player_hand(assigns) do
    ~H"""
    <div class="text-center" data-testid={"player-hand-#{@position}"}>
      <div class={[
        "badge badge-lg mb-2 transition-all duration-300",
        if(@current,
          do: "badge-primary shadow-lg scale-110 animate-pulse",
          else: "badge-ghost opacity-70"
        )
      ]}>
        {position_name(@position)}
        {if @current, do: " 🎯", else: ""}
      </div>
      <div class="flex gap-1 flex-wrap justify-center max-w-md">
        <%= if @position == "south" and assigns[:playable] do %>
          <%= for card <- @player.hand do %>
            <.card_component
              card={card}
              clickable={card_playable?(@game, card)}
              data_testid={"card-#{card.suit}-#{card.rank}"}
            />
          <% end %>
        <% else %>
          <%= for _card <- @player.hand do %>
            <.card_back />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # Composant pli en cours
  defp current_trick(assigns) do
    ~H"""
    <div class="text-center">
      <div class="badge badge-secondary mb-2">Pli en cours</div>
      <div class="grid grid-cols-2 gap-4 w-64 h-64">
        <%= for {card, position} <- @trick.cards do %>
          <div class={trick_card_position(position)}>
            <.card_component card={card} clickable={false} />
          </div>
        <% end %>
      </div>
      <%= if @trick.cards == [] do %>
        <p class="text-white text-sm mt-4">Aucune carte jouée</p>
      <% end %>
    </div>
    """
  end

  # Composant carte visible
  defp card_component(assigns) do
    assigns =
      assigns
      |> assign_new(:enlarged, fn -> false end)
      |> assign_new(:data_testid, fn -> nil end)
      |> assign(:size_classes, if(assigns[:enlarged], do: "w-32 h-48", else: "w-16 h-24"))
      |> assign(:rank_size, if(assigns[:enlarged], do: "text-3xl", else: "text-xl"))
      |> assign(:suit_size, if(assigns[:enlarged], do: "text-6xl", else: "text-3xl"))

    ~H"""
    <div
      phx-click={if @clickable, do: "play_card"}
      phx-value-card={"#{@card.rank}_#{@card.suit}"}
      data-testid={@data_testid}
      data-playable={to_string(@clickable)}
      class={[
        "card bg-white shadow-lg border-2 transition-all",
        @size_classes,
        if(@clickable,
          do: "hover:scale-110 hover:shadow-2xl border-blue-500 cursor-pointer",
          else: "border-gray-300"
        ),
        if(!@clickable, do: "opacity-50")
      ]}
    >
      <div class="card-body p-2 flex flex-col justify-between">
        <span class={"#{@rank_size} font-bold #{card_color(@card)}"}>
          {format_rank(@card.rank)}
        </span>
        <span class={"#{@suit_size} #{card_color(@card)}"}>
          {format_suit(@card.suit)}
        </span>
      </div>
    </div>
    """
  end

  # Composant dos de carte
  defp card_back(assigns) do
    ~H"""
    <div class="card bg-blue-900 w-16 h-24 shadow-lg border-2 border-blue-700">
      <div class="card-body p-2 flex items-center justify-center">
        <span class="text-4xl">🃏</span>
      </div>
    </div>
    """
  end

  # Helpers de formatage
  defp position_name("north"), do: "Marcel 🤖"
  defp position_name("south"), do: "Vous"
  defp position_name("east"), do: "Josette 🤖"
  defp position_name("west"), do: "René 🤖"

  defp format_rank(:seven), do: "7"
  defp format_rank(:eight), do: "8"
  defp format_rank(:nine), do: "9"
  defp format_rank(:ten), do: "10"
  defp format_rank(:jack), do: "V"
  defp format_rank(:queen), do: "D"
  defp format_rank(:king), do: "R"
  defp format_rank(:ace), do: "A"

  defp format_suit(:spades), do: "♠"
  defp format_suit(:hearts), do: "♥"
  defp format_suit(:diamonds), do: "♦"
  defp format_suit(:clubs), do: "♣"

  defp card_color(%Card{suit: suit}) when suit in [:hearts, :diamonds], do: "text-red-600 dark:text-red-500"
  defp card_color(%Card{suit: suit}) when suit in [:spades, :clubs], do: "text-gray-900 dark:text-gray-800"

  # South
  defp trick_card_position(0), do: "col-start-1 row-start-2 self-end"
  # East
  defp trick_card_position(1), do: "col-start-2 row-start-2 self-center justify-self-end"
  # North
  defp trick_card_position(2), do: "col-start-1 row-start-1 self-start"
  # West
  defp trick_card_position(3), do: "col-start-1 row-start-2 self-center justify-self-start"
end
