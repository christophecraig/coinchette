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
    <div class="min-h-screen bg-gradient-to-br from-green-800 to-green-600 p-8">
      <div class="max-w-6xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-white mb-2">🃏 Coinchette</h1>
          <p class="text-green-100 text-lg">{@message}</p>
          <div class="mt-4">
            <button
              phx-click="new_game"
              class="btn btn-primary"
            >
              Nouvelle Partie
            </button>
          </div>
        </div>
        
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
        
    <!-- Score et info -->
        <.score_panel game={@game} />
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
                  >
                    ✅ Je prends
                  </button>
                  <button
                    phx-click="bid_pass"
                    class="btn btn-ghost flex-1"
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
  defp game_board(assigns) do
    ~H"""
    <div class="relative bg-green-700 rounded-3xl shadow-2xl p-12 min-h-[600px]">
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

  # Composant panneau de score
  defp score_panel(assigns) do
    ~H"""
    <%= if @game.status == :playing or @game.status == :finished or Game.game_over?(@game) do %>
      <div class="mt-8 grid grid-cols-2 gap-4">
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">📊 Score</h2>
            <div class="space-y-3">
              <div class="flex justify-between items-center">
                <div class="flex items-center gap-2">
                  <span>Équipe 0 (Vous + Nord):</span>
                  <%= if @game.belote_rebelote && elem(@game.belote_rebelote, 0) == 0 do %>
                    <span class="badge badge-success badge-sm">👑 +20</span>
                  <% end %>
                  <%= if @game.announcements_result && @game.announcements_result.winning_team == 0 && @game.announcements_result.total_points > 0 do %>
                    <span class="badge badge-info badge-sm">
                      🎺 +{@game.announcements_result.total_points}
                    </span>
                  <% end %>
                </div>
                <div class="text-right">
                  <span class="font-bold text-2xl text-primary">
                    {@game.scores[0]}
                  </span>
                  <span class="text-sm text-base-content/60"> pts</span>
                  <div class="text-xs text-base-content/50">
                    {@game.tricks_won |> Enum.count(fn {team, _} -> team == 0 end)} plis
                  </div>
                </div>
              </div>
              <div class="divider my-0"></div>
              <div class="flex justify-between items-center">
                <div class="flex items-center gap-2">
                  <span>Équipe 1 (Est + Ouest):</span>
                  <%= if @game.belote_rebelote && elem(@game.belote_rebelote, 0) == 1 do %>
                    <span class="badge badge-success badge-sm">👑 +20</span>
                  <% end %>
                  <%= if @game.announcements_result && @game.announcements_result.winning_team == 1 && @game.announcements_result.total_points > 0 do %>
                    <span class="badge badge-info badge-sm">
                      🎺 +{@game.announcements_result.total_points}
                    </span>
                  <% end %>
                </div>
                <div class="text-right">
                  <span class="font-bold text-2xl text-secondary">
                    {@game.scores[1]}
                  </span>
                  <span class="text-sm text-base-content/60"> pts</span>
                  <div class="text-xs text-base-content/50">
                    {@game.tricks_won |> Enum.count(fn {team, _} -> team == 1 end)} plis
                  </div>
                </div>
              </div>
              <%= if Game.game_over?(@game) do %>
                <div class="alert alert-success mt-2">
                  <span class="text-sm">
                    <%= if @game.scores[0] > @game.scores[1] do %>
                      🎉 Victoire ! Vous gagnez {@game.scores[0]} - {@game.scores[1]}
                    <% else %>
                      😢 Défaite. Score: {@game.scores[0]} - {@game.scores[1]}
                    <% end %>
                  </span>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">ℹ️ Info</h2>
            <div class="space-y-2 text-sm">
              <p><strong>Atout:</strong> {format_suit(@game.trump_suit)}</p>
              <p><strong>Plis joués:</strong> {length(@game.tricks_won)} / 8</p>
              <p><strong>Total points:</strong> 162</p>
              <%= if length(@game.tricks_won) == 8 do %>
                <p class="text-success"><strong>Dix de der:</strong> ✅ +10 pts</p>
              <% end %>
              <p>
                <strong>Statut:</strong> {if Game.game_over?(@game), do: "Terminé", else: "En cours"}
              </p>
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
    <div class="text-center">
      <div class="badge badge-lg mb-2" class={if @current, do: "badge-primary", else: "badge-ghost"}>
        {position_name(@position)}
        {if @current, do: "🎯", else: ""}
      </div>
      <div class="flex gap-1 flex-wrap justify-center max-w-md">
        <%= if @position == "south" and assigns[:playable] do %>
          <%= for card <- @player.hand do %>
            <.card_component
              card={card}
              clickable={card_playable?(@game, card)}
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
      |> assign(:size_classes, if(assigns[:enlarged], do: "w-32 h-48", else: "w-16 h-24"))
      |> assign(:rank_size, if(assigns[:enlarged], do: "text-3xl", else: "text-xl"))
      |> assign(:suit_size, if(assigns[:enlarged], do: "text-6xl", else: "text-3xl"))

    ~H"""
    <div
      phx-click={if @clickable, do: "play_card"}
      phx-value-card={"#{@card.rank}_#{@card.suit}"}
      class={[
        "card bg-white shadow-lg border-2 transition-all",
        @size_classes,
        if(@clickable,
          do: "hover:scale-110 hover:shadow-2xl border-blue-500 cursor-pointer",
          else: "border-gray-300"
        )
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
  defp position_name("north"), do: "Nord (Bot)"
  defp position_name("south"), do: "Vous (Sud)"
  defp position_name("east"), do: "Est (Bot)"
  defp position_name("west"), do: "Ouest (Bot)"

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

  defp card_color(%Card{suit: suit}) when suit in [:hearts, :diamonds], do: "text-red-600"
  defp card_color(%Card{suit: suit}) when suit in [:spades, :clubs], do: "text-black"

  # South
  defp trick_card_position(0), do: "col-start-1 row-start-2 self-end"
  # East
  defp trick_card_position(1), do: "col-start-2 row-start-2 self-center justify-self-end"
  # North
  defp trick_card_position(2), do: "col-start-1 row-start-1 self-start"
  # West
  defp trick_card_position(3), do: "col-start-1 row-start-2 self-center justify-self-start"
end
