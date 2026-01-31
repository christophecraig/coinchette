defmodule Coinchette.Games.Rules do
  @moduledoc """
  Implémente les règles officielles FFB de belote/coinche.

  Gère les obligations de jeu:
  - Fournir la couleur demandée si possible
  - Couper avec atout si pas la couleur
  - Surcouper si possible (sauf sur partenaire)
  - Exception partenaire maître
  """

  alias Coinchette.Games.{Card, Trick, Player}

  @doc """
  Retourne les cartes légales jouables selon les règles FFB.

  ## Paramètres
    * `player` - Le joueur
    * `trick` - Le pli en cours
    * `trump_suit` - La couleur d'atout
    * `player_position` - Position du joueur (pour déterminer partenaire)

  ## Exemples

      iex> hand = [Card.new(:ace, :spades), Card.new(:king, :hearts)]
      iex> player = Player.new(0, hand)
      iex> trick = Trick.new()
      iex> Rules.valid_cards(player, trick, :hearts, 0)
      [Card.new(:ace, :spades), Card.new(:king, :hearts)]
  """
  def valid_cards(%Player{hand: hand}, %Trick{cards: []}, _trump_suit, _position) do
    # Premier joueur, peut jouer n'importe quoi
    hand
  end

  def valid_cards(%Player{hand: hand} = player, trick, trump_suit, position) do
    led_suit = trick.led_suit
    cards_in_led_suit = Player.cards_of_suit(player, led_suit)

    cond do
      # Cas 1: A des cartes de la couleur demandée
      length(cards_in_led_suit) > 0 ->
        cards_in_led_suit

      # Cas 2: Pas la couleur, doit gérer atouts
      true ->
        handle_no_led_suit(hand, trick, trump_suit, position)
    end
  end

  @doc """
  Vérifie si une carte spécifique peut être jouée.

  ## Exemples

      iex> Rules.can_play_card?(player, trick, :hearts, 0, card)
      true
  """
  def can_play_card?(player, trick, trump_suit, position, card) do
    valid = valid_cards(player, trick, trump_suit, position)
    card in valid
  end

  # Gestion quand le joueur n'a pas la couleur demandée
  defp handle_no_led_suit(hand, trick, trump_suit, position) do
    trumps_in_hand = Enum.filter(hand, fn card -> card.suit == trump_suit end)
    trumps_in_trick = Enum.filter(trick.cards, fn {card, _pos} -> card.suit == trump_suit end)

    cond do
      # Cas 2a: Pas d'atouts en main, peut défausser n'importe quoi
      trumps_in_hand == [] ->
        hand

      # Cas 2b: Des atouts dans le pli
      trumps_in_trick != [] ->
        handle_trumps_in_trick(hand, trumps_in_hand, trumps_in_trick, trick, trump_suit, position)

      # Cas 2c: Pas d'atouts dans le pli, mais partenaire gagne
      partner_winning?(trick, trump_suit, position) ->
        # Peut défausser ou couper (pas d'obligation)
        hand

      # Cas 2d: Pas d'atouts dans le pli, doit couper
      true ->
        trumps_in_hand
    end
  end

  # Gestion quand des atouts ont été joués
  defp handle_trumps_in_trick(
         _hand,
         trumps_in_hand,
         trumps_in_trick,
         _trick,
         trump_suit,
         position
       ) do
    # Vérifier si le partenaire a le plus fort atout
    if partner_has_highest_trump?(trumps_in_trick, position) do
      # Partenaire a le plus fort atout, peut jouer n'importe quel atout
      trumps_in_hand
    else
      # Adversaire a le plus fort atout, doit surcouper si possible
      highest_trump = find_highest_trump(trumps_in_trick, trump_suit)
      higher_trumps = filter_higher_trumps(trumps_in_hand, highest_trump, trump_suit)

      if higher_trumps == [] do
        # Cannot overtrump, can play any trump
        trumps_in_hand
      else
        # Must overtrump
        higher_trumps
      end
    end
  end

  # Vérifie si le partenaire est en train de gagner (pas d'atouts joués)
  defp partner_winning?(trick, trump_suit, position) do
    case trick.cards do
      [] ->
        false

      cards when length(cards) < 4 ->
        # Pli incomplet, calculer le gagnant temporaire
        winning_pos = calculate_temp_winner(cards, trump_suit)
        same_team?(position, winning_pos)

      _ ->
        # Pli complet
        winning_pos = Trick.winner(trick, trump_suit)
        same_team?(position, winning_pos)
    end
  end

  # Calcule le gagnant temporaire d'un pli incomplet
  defp calculate_temp_winner(cards, trump_suit) do
    led_suit = elem(hd(cards), 0).suit

    # Séparer trumps et non-trumps
    {trumps, non_trumps} = Enum.split_with(cards, fn {card, _pos} -> card.suit == trump_suit end)

    winner_card_pos =
      if trumps != [] do
        find_highest_card(trumps, trump_suit)
      else
        led_suit_cards = Enum.filter(non_trumps, fn {card, _pos} -> card.suit == led_suit end)
        find_highest_card(led_suit_cards, trump_suit)
      end

    elem(winner_card_pos, 1)
  end

  # Trouve la carte la plus forte dans une liste
  defp find_highest_card([first | rest], trump_suit) do
    Enum.reduce(rest, first, fn {card, _pos} = current, {best_card, _best_pos} = best ->
      if Card.strength(card, trump_suit) > Card.strength(best_card, trump_suit) do
        current
      else
        best
      end
    end)
  end

  # Vérifie si le partenaire a le plus fort atout dans le pli
  defp partner_has_highest_trump?(trumps_in_trick, position) do
    case trumps_in_trick do
      [] ->
        false

      [{_card, trump_pos} | rest] ->
        highest_trump_pos =
          Enum.reduce(rest, trump_pos, fn {card, pos}, acc_pos ->
            {acc_card, _} = Enum.find(trumps_in_trick, fn {_c, p} -> p == acc_pos end)

            if Card.strength(card, card.suit) > Card.strength(acc_card, acc_card.suit) do
              pos
            else
              acc_pos
            end
          end)

        same_team?(position, highest_trump_pos)
    end
  end

  # Trouve le plus fort atout dans une liste
  defp find_highest_trump(trumps, trump_suit) do
    trumps
    |> Enum.max_by(fn {card, _pos} -> Card.strength(card, trump_suit) end)
    |> elem(0)
  end

  # Filtre les atouts plus forts qu'un atout donné
  defp filter_higher_trumps(trumps, highest_trump, trump_suit) do
    highest_strength = Card.strength(highest_trump, trump_suit)

    Enum.filter(trumps, fn card ->
      Card.strength(card, trump_suit) > highest_strength
    end)
  end

  # Vérifie si deux positions sont dans la même équipe
  defp same_team?(pos1, pos2) do
    rem(pos1, 2) == rem(pos2, 2)
  end
end
