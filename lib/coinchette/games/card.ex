defmodule Coinchette.Games.Card do
  @moduledoc """
  Représente une carte à jouer de belote/coinche.

  Une carte possède une valeur (7 à As) et une couleur (Pique, Cœur, Carreau, Trèfle).
  La valeur en points d'une carte dépend de si elle est atout ou non.
  """

  @type rank ::
          :seven | :eight | :nine | :ten | :jack | :queen | :king | :ace

  @type suit :: :spades | :hearts | :diamonds | :clubs

  @type t :: %__MODULE__{
          rank: rank(),
          suit: suit()
        }

  defstruct [:rank, :suit]

  @doc """
  Crée une nouvelle carte.

  ## Exemples

      iex> Card.new(:ace, :spades)
      %Card{rank: :ace, suit: :spades}
  """
  def new(rank, suit) when rank in [:seven, :eight, :nine, :ten, :jack, :queen, :king, :ace] and
                             suit in [:spades, :hearts, :diamonds, :clubs] do
    %__MODULE__{rank: rank, suit: suit}
  end

  @doc """
  Retourne la valeur en points de la carte.

  La valeur dépend de si la carte est atout ou non selon les règles FFB.

  ## Paramètres

    * `card` - La carte à évaluer
    * `trump_suit` - La couleur d'atout

  ## Exemples

      iex> card = Card.new(:jack, :hearts)
      iex> Card.value(card, :hearts)
      20

      iex> card = Card.new(:jack, :spades)
      iex> Card.value(card, :hearts)
      2
  """
  def value(%__MODULE__{rank: rank, suit: suit}, trump_suit) do
    if suit == trump_suit do
      trump_value(rank)
    else
      non_trump_value(rank)
    end
  end

  # Valeurs des cartes atout selon règles FFB
  defp trump_value(:jack), do: 20
  defp trump_value(:nine), do: 14
  defp trump_value(:ace), do: 11
  defp trump_value(:ten), do: 10
  defp trump_value(:king), do: 4
  defp trump_value(:queen), do: 3
  defp trump_value(:eight), do: 0
  defp trump_value(:seven), do: 0

  # Valeurs des cartes non-atout selon règles FFB
  defp non_trump_value(:ace), do: 11
  defp non_trump_value(:ten), do: 10
  defp non_trump_value(:king), do: 4
  defp non_trump_value(:queen), do: 3
  defp non_trump_value(:jack), do: 2
  defp non_trump_value(:nine), do: 0
  defp non_trump_value(:eight), do: 0
  defp non_trump_value(:seven), do: 0

  @doc """
  Retourne la force de la carte pour déterminer le gagnant d'un pli.

  Différent de value/2 qui retourne les points. Cette fonction
  détermine quelle carte "bat" l'autre, même si elles ont 0 points.

  ## Exemples

      iex> card = Card.new(:nine, :spades)
      iex> Card.strength(card, :hearts)
      9
  """
  def strength(%__MODULE__{rank: rank, suit: suit}, trump_suit) do
    if suit == trump_suit do
      trump_strength(rank)
    else
      non_trump_strength(rank)
    end
  end

  # Force des atouts (ordre de victoire)
  defp trump_strength(:jack), do: 20
  defp trump_strength(:nine), do: 14
  defp trump_strength(:ace), do: 11
  defp trump_strength(:ten), do: 10
  defp trump_strength(:king), do: 4
  defp trump_strength(:queen), do: 3
  defp trump_strength(:eight), do: 2
  defp trump_strength(:seven), do: 1

  # Force des non-atouts (ordre standard des cartes)
  defp non_trump_strength(:ace), do: 14
  defp non_trump_strength(:ten), do: 10
  defp non_trump_strength(:king), do: 9
  defp non_trump_strength(:queen), do: 8
  defp non_trump_strength(:jack), do: 7
  defp non_trump_strength(:nine), do: 6
  defp non_trump_strength(:eight), do: 5
  defp non_trump_strength(:seven), do: 4

  defimpl String.Chars do
    @moduledoc """
    Conversion d'une carte en chaîne de caractères lisible.
    """
    def to_string(card) do
      rank_name = rank_to_string(card.rank)
      suit_name = suit_to_string(card.suit)
      "#{rank_name} of #{suit_name}"
    end

    defp rank_to_string(:seven), do: "Seven"
    defp rank_to_string(:eight), do: "Eight"
    defp rank_to_string(:nine), do: "Nine"
    defp rank_to_string(:ten), do: "Ten"
    defp rank_to_string(:jack), do: "Jack"
    defp rank_to_string(:queen), do: "Queen"
    defp rank_to_string(:king), do: "King"
    defp rank_to_string(:ace), do: "Ace"

    defp suit_to_string(:spades), do: "Spades"
    defp suit_to_string(:hearts), do: "Hearts"
    defp suit_to_string(:diamonds), do: "Diamonds"
    defp suit_to_string(:clubs), do: "Clubs"
  end
end
