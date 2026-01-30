defmodule Coinchette.Games.Player do
  @moduledoc """
  Représente un joueur de belote/coinche.

  Un joueur a une position à la table (0-3), une main de cartes,
  et appartient à une équipe (0 ou 1) selon sa position.

  Positions et équipes:
  - Position 0 (Nord) → Équipe 0
  - Position 1 (Est) → Équipe 1
  - Position 2 (Sud) → Équipe 0
  - Position 3 (Ouest) → Équipe 1
  """

  alias Coinchette.Games.Card

  @type position :: 0..3
  @type team :: 0 | 1

  @type t :: %__MODULE__{
          position: position(),
          hand: list(Card.t()),
          team: team()
        }

  defstruct [:position, :hand, :team]

  @doc """
  Crée un nouveau joueur avec une position et une main.

  L'équipe est automatiquement assignée selon la position:
  - Positions 0 et 2 → Équipe 0
  - Positions 1 et 3 → Équipe 1

  ## Exemples

      iex> player = Player.new(0, [])
      iex> player.position
      0
      iex> player.team
      0

      iex> player = Player.new(1, [])
      iex> player.team
      1
  """
  def new(position, hand) when position in 0..3 do
    %__MODULE__{
      position: position,
      hand: hand,
      team: rem(position, 2)
    }
  end

  @doc """
  Joue une carte de la main du joueur.

  Retourne {updated_player, played_card} si la carte est dans la main,
  ou {:error, :card_not_in_hand} sinon.

  ## Exemples

      iex> card = Card.new(:ace, :spades)
      iex> player = Player.new(0, [card])
      iex> {updated, played} = Player.play_card(player, card)
      iex> played == card
      true
      iex> updated.hand
      []
  """
  def play_card(%__MODULE__{hand: hand} = player, card) do
    if card in hand do
      updated_hand = List.delete(hand, card)
      {%{player | hand: updated_hand}, card}
    else
      {:error, :card_not_in_hand}
    end
  end

  @doc """
  Vérifie si le joueur a une carte spécifique dans sa main.

  ## Exemples

      iex> card = Card.new(:ace, :spades)
      iex> player = Player.new(0, [card])
      iex> Player.has_card?(player, card)
      true
  """
  def has_card?(%__MODULE__{hand: hand}, card) do
    card in hand
  end

  @doc """
  Retourne toutes les cartes d'une couleur donnée dans la main du joueur.

  ## Exemples

      iex> spades_ace = Card.new(:ace, :spades)
      iex> hearts_king = Card.new(:king, :hearts)
      iex> player = Player.new(0, [spades_ace, hearts_king])
      iex> spades = Player.cards_of_suit(player, :spades)
      iex> length(spades)
      1
  """
  def cards_of_suit(%__MODULE__{hand: hand}, suit) do
    Enum.filter(hand, fn card -> card.suit == suit end)
  end

  @doc """
  Retourne le nombre de cartes dans la main du joueur.

  ## Exemples

      iex> player = Player.new(0, [Card.new(:ace, :spades)])
      iex> Player.hand_size(player)
      1
  """
  def hand_size(%__MODULE__{hand: hand}) do
    length(hand)
  end
end
