defmodule Coinchette.Games.Game do
  @moduledoc """
  Représente une partie de belote/coinche et orchestre le flow de jeu.

  Gère la state machine du jeu:
  - waiting: En attente de joueurs
  - playing: Partie en cours
  - finished: Partie terminée

  Coordonne les modules Card, Deck, Player et Trick pour une partie complète.
  """

  alias Coinchette.Games.{Card, Deck, Player, Trick, Rules}

  @type status :: :waiting | :playing | :finished

  @type t :: %__MODULE__{
          trump_suit: Card.suit(),
          status: status(),
          players: list(Player.t()),
          current_trick: Trick.t() | nil,
          current_player_position: Player.position(),
          tricks_won: list({team :: Player.team(), Trick.t()})
        }

  defstruct [
    :trump_suit,
    status: :waiting,
    players: [],
    current_trick: nil,
    current_player_position: 0,
    tricks_won: []
  ]

  @doc """
  Crée une nouvelle partie avec une couleur d'atout.

  ## Exemples

      iex> game = Game.new(:hearts)
      iex> game.trump_suit
      :hearts
      iex> game.status
      :waiting
  """
  def new(trump_suit) when trump_suit in [:spades, :hearts, :diamonds, :clubs] do
    %__MODULE__{trump_suit: trump_suit}
  end

  @doc """
  Distribue les cartes à 4 joueurs et démarre la partie.

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

    %{game |
      players: players,
      status: :playing,
      current_trick: Trick.new()
    }
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
  Retourne l'équipe gagnante (celle avec le plus de plis).

  ## Exemples

      iex> game = %Game{tricks_won: [{0, nil}, {0, nil}, {1, nil}]}
      iex> Game.winner(game)
      0
  """
  def winner(%__MODULE__{tricks_won: tricks}) do
    tricks_by_team =
      Enum.group_by(tricks, fn {team, _trick} -> team end)
      |> Enum.map(fn {team, team_tricks} -> {team, length(team_tricks)} end)
      |> Enum.sort_by(fn {_team, count} -> count end, :desc)

    case tricks_by_team do
      [{winning_team, _count} | _rest] -> winning_team
      [] -> nil
    end
  end

  # Fonctions privées

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

      %{game |
        tricks_won: game.tricks_won ++ [{winning_team, trick}],
        current_trick: Trick.new(),
        current_player_position: winning_position
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
end
