defmodule Coinchette.Games.Deck do
  @moduledoc """
  Représente un jeu de 32 cartes de belote/coinche.

  Un deck contient toutes les cartes (7 à As) pour les 4 couleurs.
  Il peut être mélangé et distribué selon les règles FFB.
  """

  alias Coinchette.Games.Card

  @type t :: %__MODULE__{
          cards: list(Card.t())
        }

  defstruct cards: []

  @ranks [:seven, :eight, :nine, :ten, :jack, :queen, :king, :ace]
  @suits [:spades, :hearts, :diamonds, :clubs]

  @doc """
  Crée un nouveau jeu de 32 cartes dans l'ordre.

  ## Exemples

      iex> deck = Deck.new()
      iex> length(deck.cards)
      32
  """
  def new do
    cards =
      for suit <- @suits,
          rank <- @ranks do
        Card.new(rank, suit)
      end

    %__MODULE__{cards: cards}
  end

  @doc """
  Mélange les cartes du deck de manière aléatoire.

  ## Exemples

      iex> deck = Deck.new()
      iex> shuffled = Deck.shuffle(deck)
      iex> length(shuffled.cards)
      32
  """
  def shuffle(%__MODULE__{cards: cards}) do
    %__MODULE__{cards: Enum.shuffle(cards)}
  end

  @doc """
  Distribue les cartes selon les règles FFB de la belote.

  Retourne un tuple {hands, talon} où:
  - hands est une liste de 4 mains de 8 cartes chacune
  - talon est vide (toutes les cartes sont distribuées)

  Distribution FFB: 3-2-3 cartes par tour pour chaque joueur.

  ## Exemples

      iex> deck = Deck.new() |> Deck.shuffle()
      iex> {hands, talon} = Deck.deal(deck)
      iex> length(hands)
      4
      iex> Enum.all?(hands, fn hand -> length(hand) == 8 end)
      true
  """
  def deal(%__MODULE__{cards: cards}) do
    # Distribution FFB: 3-2-3 cartes par joueur
    # Premier tour: 3 cartes chacun (12 cartes)
    {first_round, remaining} = Enum.split(cards, 12)
    first_hands = distribute_round(first_round, 3)

    # Deuxième tour: 2 cartes chacun (8 cartes)
    {second_round, remaining} = Enum.split(remaining, 8)
    second_hands = distribute_round(second_round, 2)

    # Troisième tour: 3 cartes chacun (12 cartes)
    {third_round, talon} = Enum.split(remaining, 12)
    third_hands = distribute_round(third_round, 3)

    # Combiner les tours pour chaque joueur
    hands =
      for i <- 0..3 do
        Enum.at(first_hands, i) ++ Enum.at(second_hands, i) ++ Enum.at(third_hands, i)
      end

    {hands, talon}
  end

  @doc """
  Retourne le nombre de cartes restantes dans le deck.

  ## Exemples

      iex> deck = Deck.new()
      iex> Deck.remaining_cards(deck)
      32
  """
  def remaining_cards(%__MODULE__{cards: cards}) do
    length(cards)
  end

  # Distribue N cartes à chaque joueur pour un tour
  defp distribute_round(cards, cards_per_player) do
    cards
    |> Enum.chunk_every(cards_per_player)
  end
end
