defmodule Coinchette.Games.Game do
  @moduledoc """
  Représente une partie de belote/coinche et orchestre le flow de jeu.

  Gère la state machine du jeu:
  - waiting: En attente de joueurs
  - bidding: Phase d'enchères en cours
  - bidding_completed: Enchères terminées avec succès
  - bidding_failed: Tous ont passé, redistribution nécessaire
  - playing: Partie en cours
  - finished: Partie terminée

  Coordonne les modules Card, Deck, Player, Trick et Bidding pour une partie complète.
  """

  alias Coinchette.Games.{Card, Deck, Player, Trick, Rules, Score, Bidding, Announcements}

  @type status ::
          :waiting
          | :bidding
          | :bidding_completed
          | :bidding_failed
          | :announcing
          | :playing
          | :finished

  @type t :: %__MODULE__{
          trump_suit: Card.suit() | nil,
          status: status(),
          players: list(Player.t()),
          current_trick: Trick.t() | nil,
          current_player_position: Player.position(),
          tricks_won: list({team :: Player.team(), Trick.t()}),
          scores: %{Player.team() => integer()},
          dealer_position: Player.position(),
          talon: list(Card.t()),
          proposed_trump_card: Card.t() | nil,
          bidding: Bidding.t() | nil,
          belote_announced: {Player.position(), :king | :queen} | nil,
          belote_rebelote: {Player.team(), boolean()} | nil,
          announcements_result: Announcements.announcement_result() | nil,
          announcement_phase_complete: boolean()
        }

  defstruct [
    :trump_suit,
    :proposed_trump_card,
    :bidding,
    :belote_announced,
    :belote_rebelote,
    :announcements_result,
    status: :waiting,
    players: [],
    current_trick: nil,
    current_player_position: 0,
    tricks_won: [],
    scores: %{0 => 0, 1 => 0},
    dealer_position: 0,
    talon: [],
    announcement_phase_complete: false
  ]

  @doc """
  Crée une nouvelle partie.

  ## Options

    * `:dealer_position` - Position du donneur (0-3), défaut: 0
    * `:trump_suit` - Couleur d'atout (optionnel, déterminé par enchères si absent)

  ## Exemples

      # Nouvelle partie avec enchères
      iex> game = Game.new()
      iex> game.trump_suit
      nil
      iex> game.dealer_position
      0

      # Partie avec couleur d'atout fixe (pour tests/backward compatibility)
      iex> game = Game.new(:hearts)
      iex> game.trump_suit
      :hearts

      # Avec position du donneur
      iex> game = Game.new(dealer_position: 2)
      iex> game.dealer_position
      2
  """
  def new(opts \\ [])

  # Support ancien format : Game.new(:hearts)
  def new(trump_suit) when trump_suit in [:spades, :hearts, :diamonds, :clubs] do
    %__MODULE__{trump_suit: trump_suit}
  end

  # Nouveau format : Game.new(dealer_position: 0)
  def new(opts) when is_list(opts) do
    dealer_position = Keyword.get(opts, :dealer_position, 0)
    trump_suit = Keyword.get(opts, :trump_suit, nil)

    %__MODULE__{
      trump_suit: trump_suit,
      dealer_position: dealer_position
    }
  end

  @doc """
  Distribue les cartes à 4 joueurs et démarre la partie (mode sans enchères).

  Version simplifiée pour backward compatibility et tests.
  Pour une partie complète avec enchères, utiliser deal_initial_cards/1.

  ## Exemples

      iex> game = Game.new(:hearts) |> Game.deal_cards()
      iex> length(game.players)
      4
      iex> game.status
      :playing
  """
  def deal_cards(%__MODULE__{} = game) do
    deck = Deck.new() |> Deck.shuffle()
    {hands, _talon} = Deck.deal(deck)

    players =
      hands
      |> Enum.with_index()
      |> Enum.map(fn {hand, position} -> Player.new(position, hand) end)

    %{game | players: players, status: :playing, current_trick: Trick.new()}
  end

  @doc """
  Distribue les cartes initiales (5 cartes par joueur + talon de 3).

  Selon les règles FFB :
  - Distribution en 2 fois : 3 cartes puis 2 cartes = 5 cartes/joueur
  - Reste 3 cartes au talon
  - Dernière carte du talon retournée = proposition d'atout
  - Initialise la phase d'enchères

  ## Exemples

      iex> game = Game.new() |> Game.deal_initial_cards()
      iex> Enum.all?(game.players, fn p -> length(p.hand) == 5 end)
      true
      iex> length(game.talon)
      3
      iex> game.status
      :bidding
  """
  def deal_initial_cards(%__MODULE__{dealer_position: dealer_position} = game) do
    deck = Deck.new() |> Deck.shuffle()

    # Distribution spéciale : 5 cartes par joueur (3+2) + talon de 3
    {hands, talon} = deal_initial(deck)

    players =
      hands
      |> Enum.with_index()
      |> Enum.map(fn {hand, position} -> Player.new(position, hand) end)

    # Carte retournée = dernière carte du talon
    proposed_card = List.last(talon)

    # Initialiser la phase d'enchères
    bidding = Bidding.new(proposed_card, dealer_position: dealer_position)

    %{
      game
      | players: players,
        talon: talon,
        proposed_trump_card: proposed_card,
        bidding: bidding,
        status: :bidding
    }
  end

  @doc """
  Effectue une enchère pendant la phase d'enchères.

  ## Paramètres

    * `game` - Partie en cours avec status :bidding
    * `action` - Action du joueur : :take, :pass, ou {:choose, suit}

  ## Retour

    * `{:ok, updated_game}` si enchère valide
    * `{:error, reason}` sinon

  ## Exemples

      iex> game = Game.new() |> Game.deal_initial_cards()
      iex> {:ok, updated} = Game.make_bid(game, :take)
      iex> updated.status
      :bidding_completed
  """
  def make_bid(%__MODULE__{status: :bidding_completed}, _action) do
    {:error, :bidding_already_completed}
  end

  def make_bid(%__MODULE__{status: :bidding, bidding: bidding} = game, action) do
    case Bidding.bid(bidding, action) do
      {:ok, updated_bidding} ->
        updated_game = %{game | bidding: updated_bidding}

        # Mettre à jour le statut du jeu selon le résultat des enchères
        updated_game =
          cond do
            Bidding.completed?(updated_bidding) ->
              %{updated_game | status: :bidding_completed, trump_suit: updated_bidding.trump_suit}

            Bidding.failed?(updated_bidding) ->
              %{updated_game | status: :bidding_failed}

            true ->
              updated_game
          end

        {:ok, updated_game}

      {:error, _reason} = error ->
        error
    end
  end

  def make_bid(%__MODULE__{status: status}, _action) when status != :bidding do
    {:error, {:invalid_status, status}}
  end

  @doc """
  Complète la distribution après enchères réussies.

  Selon règles FFB :
  - Le preneur récupère les 3 cartes du talon (8 cartes total pour lui)
  - Tous les autres joueurs reçoivent 2 cartes supplémentaires (8 cartes total)
  - Démarre la phase d'annonces (status = :announcing)
  - Détecte automatiquement les annonces de tous les joueurs
  - Premier joueur = à droite du donneur

  ## Exemples

      iex> game = Game.new() |> Game.deal_initial_cards()
      iex> {:ok, game} = Game.make_bid(game, :take)
      iex> game = Game.complete_deal(game)
      iex> Enum.all?(game.players, fn p -> length(p.hand) == 8 end)
      true
      iex> game.status
      :announcing
  """
  def complete_deal(
        %__MODULE__{status: :bidding_completed, bidding: bidding, talon: talon} = game
      ) do
    taker_position = bidding.taker

    # Distribuer les cartes restantes
    # Le preneur récupère les 3 cartes du talon
    # Les autres reçoivent 2 cartes chacun (2 x 3 = 6 cartes)
    # Total : 3 (talon) + 6 (autres) = 9 cartes restantes
    # Mais on n'en a que 9 dans un deck de 32 (32 - 20 distribuées - 3 talon = 9)

    deck = Deck.new() |> Deck.shuffle()
    all_cards = Deck.all_cards(deck)

    # Cartes déjà distribuées
    distributed_cards = Enum.flat_map(game.players, fn player -> player.hand end) ++ talon

    # Cartes restantes dans le deck
    remaining_cards =
      all_cards
      |> Enum.reject(fn card ->
        Enum.any?(distributed_cards, fn dist_card ->
          card.suit == dist_card.suit && card.rank == dist_card.rank
        end)
      end)

    # Le preneur reçoit le talon + 0 cartes supplémentaires (déjà 5+3=8)
    # Les autres reçoivent 3 cartes chacun (5+3=8)
    # Total à distribuer : 3 x 3 = 9 cartes

    {extra_cards, _} = Enum.split(remaining_cards, 9)

    # Distribuer 3 cartes à chaque joueur sauf le preneur
    updated_players =
      game.players
      |> Enum.with_index()
      |> Enum.map(fn {player, idx} ->
        if idx == taker_position do
          # Le preneur récupère le talon
          %{player | hand: player.hand ++ talon}
        else
          # Les autres reçoivent 3 cartes
          # Calculer l'offset dans extra_cards
          offset =
            if idx < taker_position do
              idx * 3
            else
              (idx - 1) * 3
            end

          new_cards = Enum.slice(extra_cards, offset, 3)
          %{player | hand: player.hand ++ new_cards}
        end
      end)

    # Passer en phase d'annonces et détecter automatiquement
    game
    |> Map.put(:players, updated_players)
    |> Map.put(:talon, [])
    |> Map.put(:status, :announcing)
    |> Map.put(:current_player_position, rem(game.dealer_position + 1, 4))
    |> detect_and_process_announcements()
  end

  @doc """
  Complète la phase d'annonces et démarre la partie.

  Transition de :announcing vers :playing.
  Les annonces ont déjà été détectées et stockées dans game.announcements_result.

  ## Exemples

      iex> game = game |> Game.complete_announcements()
      iex> game.status
      :playing
  """
  def complete_announcements(%__MODULE__{status: :announcing} = game) do
    %{game | status: :playing, current_trick: Trick.new()}
  end

  # Détecte automatiquement les annonces de tous les joueurs
  defp detect_and_process_announcements(%__MODULE__{} = game) do
    first_player = rem(game.dealer_position + 1, 4)

    # Détecter pour tous les joueurs
    all_announcements =
      Enum.map(game.players, fn player ->
        announcements = Announcements.detect_all(player.hand, game.trump_suit)
        %{player_position: player.position, team: player.team, announcements: announcements}
      end)

    # Comparer et déterminer gagnant
    result = Announcements.compare_announcements(all_announcements, first_player)

    %{
      game
      | announcements_result: result,
        announcement_phase_complete: true,
        current_trick: Trick.new()
    }
  end

  # Fonction privée pour distribution initiale
  defp deal_initial(deck) do
    all_cards = Deck.all_cards(deck) |> Enum.shuffle()

    # Distribuer 5 cartes à chaque joueur (20 cartes)
    {player_cards, rest} = Enum.split(all_cards, 20)

    # Répartir en 4 mains de 5 cartes
    hands = Enum.chunk_every(player_cards, 5)

    # Talon = 3 cartes suivantes
    {talon, _remaining} = Enum.split(rest, 3)

    {hands, talon}
  end

  @doc """
  Joue une carte pour le joueur actuel.

  Retourne {:ok, updated_game} si le coup est valide,
  ou {:error, reason} sinon.

  ## Exemples

      iex> game = Game.new(:hearts) |> Game.deal_cards()
      iex> player = Game.current_player(game)
      iex> card = List.first(player.hand)
      iex> {:ok, updated} = Game.play_card(game, card)
      iex> updated.current_player_position
      1
  """
  def play_card(%__MODULE__{status: :playing} = game, card) do
    current_player = current_player(game)

    # Valider selon les règles FFB
    if Rules.can_play_card?(
         current_player,
         game.current_trick,
         game.trump_suit,
         current_player.position,
         card
       ) do
      case Player.play_card(current_player, card) do
        {:error, reason} ->
          {:error, reason}

        {updated_player, played_card} ->
          updated_game =
            game
            |> update_player(updated_player)
            |> add_card_to_trick(played_card, current_player.position)
            |> check_and_announce_belote(played_card, current_player.position)
            |> maybe_complete_trick()
            |> advance_turn()

          {:ok, updated_game}
      end
    else
      {:error, :invalid_card}
    end
  end

  def play_card(%__MODULE__{status: status}, _card) do
    {:error, {:invalid_status, status}}
  end

  @doc """
  Fait jouer un bot automatiquement en utilisant une stratégie.

  ## Paramètres

    * `game` - La partie en cours
    * `strategy_module` - Module implémentant le behaviour Bots.Strategy

  ## Exemples

      iex> game = Game.new(:hearts) |> Game.deal_cards()
      iex> {:ok, updated} = Game.play_bot_turn(game, Coinchette.Bots.Basic)
      iex> length(updated.current_trick.cards)
      1
  """
  def play_bot_turn(%__MODULE__{status: :playing} = game, strategy_module) do
    player = current_player(game)

    # Obtenir les cartes valides selon les règles FFB
    valid_cards =
      Rules.valid_cards(
        player,
        game.current_trick,
        game.trump_suit,
        player.position
      )

    # Le bot choisit une carte
    chosen_card =
      strategy_module.choose_card(
        player,
        game.current_trick,
        game.trump_suit,
        valid_cards
      )

    # Jouer la carte choisie
    play_card(game, chosen_card)
  end

  def play_bot_turn(%__MODULE__{status: status}, _strategy_module) do
    {:error, {:invalid_status, status}}
  end

  @doc """
  Retourne le joueur dont c'est le tour de jouer.

  ## Exemples

      iex> game = Game.new(:hearts) |> Game.deal_cards()
      iex> player = Game.current_player(game)
      iex> player.position
      0
  """
  def current_player(%__MODULE__{players: players, current_player_position: position}) do
    Enum.at(players, position)
  end

  @doc """
  Vérifie si la partie est terminée (tous les plis joués).

  ## Exemples

      iex> game = Game.new(:hearts) |> Game.deal_cards()
      iex> Game.game_over?(game)
      false
  """
  def game_over?(%__MODULE__{tricks_won: tricks}) do
    length(tricks) == 8
  end

  @doc """
  Retourne l'équipe gagnante (celle avec le plus de points).

  ## Exemples

      iex> game = %Game{scores: %{0 => 100, 1 => 62}}
      iex> Game.winner(game)
      0
  """
  def winner(%__MODULE__{scores: scores}) do
    case Enum.max_by(scores, fn {_team, points} -> points end, fn -> nil end) do
      {team, _points} -> team
      nil -> nil
    end
  end

  @doc """
  Vérifie si un joueur possède le Roi ET la Dame d'atout (Belote).

  ## Exemples

      iex> player = %Player{hand: [Card.new(:king, :hearts), Card.new(:queen, :hearts)]}
      iex> Game.has_belote?(player, :hearts)
      true
  """
  def has_belote?(%Player{hand: hand}, trump_suit) do
    king = %Card{rank: :king, suit: trump_suit}
    queen = %Card{rank: :queen, suit: trump_suit}

    Enum.member?(hand, king) and Enum.member?(hand, queen)
  end

  @doc """
  Détecte et enregistre l'annonce de Belote/Rebelote lors du jeu d'une carte.

  Retourne le jeu mis à jour avec l'annonce enregistrée si applicable.
  """
  def check_and_announce_belote(%__MODULE__{} = game, %Card{} = played_card, player_position) do
    player = Enum.at(game.players, player_position)

    cond do
      # Cas 1: Joueur joue le Roi ou la Dame d'atout et a (ou avait) l'autre carte
      is_belote_card?(played_card, game.trump_suit) and
          has_belote_pair?(game, player, played_card) ->
        announce_belote_card(game, played_card, player)

      true ->
        game
    end
  end

  # Fonctions privées

  # Vérifie si la carte est le Roi ou la Dame d'atout
  defp is_belote_card?(%Card{rank: rank, suit: suit}, trump_suit)
       when rank in [:king, :queen] and suit == trump_suit do
    true
  end

  defp is_belote_card?(_, _), do: false

  # Vérifie si le joueur a (ou avait) la paire de Belote
  defp has_belote_pair?(game, player, %Card{rank: :king, suit: suit}) do
    if suit == game.trump_suit do
      queen = %Card{rank: :queen, suit: game.trump_suit}
      # La Dame est en main OU déjà jouée avec annonce
      Enum.member?(player.hand, queen) or belote_already_announced_by?(game, player.position)
    else
      false
    end
  end

  defp has_belote_pair?(game, player, %Card{rank: :queen, suit: suit}) do
    if suit == game.trump_suit do
      king = %Card{rank: :king, suit: game.trump_suit}
      # Le Roi est en main OU déjà joué avec annonce
      Enum.member?(player.hand, king) or belote_already_announced_by?(game, player.position)
    else
      false
    end
  end

  defp has_belote_pair?(_, _, _), do: false

  # Vérifie si Belote a déjà été annoncée par ce joueur
  defp belote_already_announced_by?(%__MODULE__{belote_announced: {position, _}}, player_position)
       when position == player_position do
    true
  end

  defp belote_already_announced_by?(_, _), do: false

  # Enregistre l'annonce de Belote ou Rebelote
  defp announce_belote_card(game, %Card{rank: rank}, player) do
    case game.belote_announced do
      # Première carte de Belote jouée
      nil ->
        %{game | belote_announced: {player.position, rank}}

      # Seconde carte jouée par le même joueur = Rebelote !
      {announced_position, _rank} when announced_position == player.position ->
        %{
          game
          | belote_rebelote: {player.team, true},
            # Reset après Rebelote
            belote_announced: nil
        }

      # Autre joueur, ne rien faire
      _ ->
        game
    end
  end

  defp update_player(game, updated_player) do
    updated_players =
      Enum.map(game.players, fn player ->
        if player.position == updated_player.position do
          updated_player
        else
          player
        end
      end)

    %{game | players: updated_players}
  end

  defp add_card_to_trick(game, card, position) do
    updated_trick = Trick.add_card(game.current_trick, card, position)
    %{game | current_trick: updated_trick}
  end

  defp maybe_complete_trick(%__MODULE__{current_trick: trick} = game) do
    if Trick.complete?(trick) do
      winning_position = Trick.winner(trick, game.trump_suit)
      winning_player = Enum.at(game.players, winning_position)
      winning_team = winning_player.team

      updated_tricks_won = game.tricks_won ++ [{winning_team, trick}]

      # Recalculer les scores (avec dix de der si dernier pli + belote/rebelote + annonces si premier pli)
      is_last_trick = length(updated_tricks_won) == 8
      is_first_trick = length(updated_tricks_won) == 1

      score_opts =
        []
        |> maybe_add_last_trick_winner(is_last_trick, winning_team)
        |> maybe_add_belote_rebelote(game.belote_rebelote)
        |> maybe_add_announcements(is_first_trick, game.announcements_result)

      updated_scores = Score.calculate_scores(updated_tricks_won, game.trump_suit, score_opts)

      %{
        game
        | tricks_won: updated_tricks_won,
          current_trick: Trick.new(),
          current_player_position: winning_position,
          scores: updated_scores
      }
    else
      game
    end
  end

  defp advance_turn(%__MODULE__{current_trick: trick} = game) do
    # Si le pli vient d'être complété, current_player_position
    # a déjà été mis à jour vers le gagnant, on ne bouge pas
    if Trick.complete?(trick) do
      game
    else
      # Sinon, on passe au joueur suivant
      next_position = rem(game.current_player_position + 1, 4)
      %{game | current_player_position: next_position}
    end
  end

  # Ajoute last_trick_winner aux options si c'est le dernier pli
  defp maybe_add_last_trick_winner(opts, true, winning_team) do
    Keyword.put(opts, :last_trick_winner, winning_team)
  end

  defp maybe_add_last_trick_winner(opts, false, _), do: opts

  # Ajoute belote_rebelote aux options si présent
  defp maybe_add_belote_rebelote(opts, {_team, true} = belote_rebelote) do
    Keyword.put(opts, :belote_rebelote, belote_rebelote)
  end

  defp maybe_add_belote_rebelote(opts, _), do: opts

  # Ajoute announcements aux options si c'est le premier pli et qu'il y a des annonces
  defp maybe_add_announcements(opts, true, %{winning_team: _team} = result)
       when result.total_points > 0 do
    Keyword.put(opts, :announcements, result)
  end

  defp maybe_add_announcements(opts, _, _), do: opts
end
