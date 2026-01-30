defmodule Coinchette.Games.Trick do
  @moduledoc """
  Représente un pli (trick) de belote/coinche.

  Un pli contient jusqu'à 4 cartes jouées par les 4 joueurs.
  Le gagnant est déterminé selon les règles FFB:
  - Plus forte carte de la couleur demandée (led suit)
  - OU plus fort atout si des atouts ont été joués
  - En cas d'égalité de valeur, le premier joué gagne
  """

  alias Coinchette.Games.Card

  @type t :: %__MODULE__{
          cards: list({Card.t(), player_position :: integer()}),
          led_suit: Card.suit() | nil
        }

  defstruct cards: [], led_suit: nil

  @doc """
  Crée un nouveau pli vide.

  ## Exemples

      iex> trick = Trick.new()
      iex> trick.cards
      []
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Ajoute une carte au pli.

  La première carte jouée définit la couleur demandée (led suit).
  Retourne {:error, :trick_complete} si 4 cartes ont déjà été jouées.

  ## Exemples

      iex> trick = Trick.new()
      iex> updated = Trick.add_card(trick, Card.new(:ace, :spades), 0)
      iex> updated.led_suit
      :spades
  """
  def add_card(%__MODULE__{cards: cards}, _card, _position) when length(cards) >= 4 do
    {:error, :trick_complete}
  end

  def add_card(%__MODULE__{cards: [], led_suit: nil} = trick, card, position) do
    # Première carte, définit la couleur demandée
    %{trick | cards: [{card, position}], led_suit: card.suit}
  end

  def add_card(%__MODULE__{cards: cards} = trick, card, position) do
    %{trick | cards: cards ++ [{card, position}]}
  end

  @doc """
  Vérifie si le pli est complet (4 cartes jouées).

  ## Exemples

      iex> trick = Trick.new()
      iex> Trick.complete?(trick)
      false
  """
  def complete?(%__MODULE__{cards: cards}) do
    length(cards) == 4
  end

  @doc """
  Détermine le gagnant du pli selon les règles FFB.

  Retourne la position du joueur gagnant, ou {:error, :trick_incomplete}
  si le pli n'est pas complet.

  ## Règles:
  - Sans atout joué: plus forte carte de la couleur demandée gagne
  - Avec atout(s): plus fort atout gagne
  - Égalité de valeur: premier joué gagne

  ## Exemples

      iex> trick = Trick.new()
      iex> |> Trick.add_card(Card.new(:king, :spades), 0)
      iex> |> Trick.add_card(Card.new(:ace, :spades), 1)
      iex> |> Trick.add_card(Card.new(:queen, :spades), 2)
      iex> |> Trick.add_card(Card.new(:jack, :spades), 3)
      iex> Trick.winner(trick, :hearts)
      1
  """
  def winner(%__MODULE__{cards: cards}, _trump_suit) when length(cards) < 4 do
    {:error, :trick_incomplete}
  end

  def winner(%__MODULE__{cards: cards, led_suit: led_suit}, trump_suit) do
    # Séparer les atouts et non-atouts
    {trumps, non_trumps} =
      Enum.split_with(cards, fn {card, _pos} -> card.suit == trump_suit end)

    winner_card_pos =
      if trumps != [] do
        # Des atouts ont été joués, le plus fort gagne
        find_highest(trumps, trump_suit)
      else
        # Pas d'atouts, la plus forte carte de la couleur demandée gagne
        led_suit_cards = Enum.filter(non_trumps, fn {card, _pos} -> card.suit == led_suit end)
        find_highest(led_suit_cards, trump_suit)
      end

    elem(winner_card_pos, 1)
  end

  # Trouve la carte avec la plus haute force dans une liste
  # En cas d'égalité, retourne la première (ordre de jeu)
  defp find_highest([first | rest], trump_suit) do
    Enum.reduce(rest, first, fn {card, _pos} = current, {best_card, _best_pos} = best ->
      current_strength = Card.strength(card, trump_suit)
      best_strength = Card.strength(best_card, trump_suit)

      if current_strength > best_strength do
        current
      else
        best
      end
    end)
  end
end
