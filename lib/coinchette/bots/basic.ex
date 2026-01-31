defmodule Coinchette.Bots.Basic do
  @moduledoc """
  Stratégie de bot basique pour mode solo.

  Principe simple:
  - Jouer la plus petite carte valide (stratégie conservative)
  - Préférer défausser des non-atouts quand possible
  - Respecter toujours les règles FFB
  """

  @behaviour Coinchette.Bots.Strategy

  alias Coinchette.Games.Card

  @impl true
  def choose_card(_player, _trick, trump_suit, valid_cards) do
    case valid_cards do
      # Une seule carte valide, pas de choix
      [single_card] ->
        single_card

      # Plusieurs cartes, choisir la plus petite
      multiple when length(multiple) > 1 ->
        choose_smallest_card(multiple, trump_suit)
    end
  end

  # Choisit la plus petite carte en fonction de sa force
  defp choose_smallest_card(cards, trump_suit) do
    # Séparer trumps et non-trumps
    {trumps, non_trumps} = Enum.split_with(cards, fn card -> card.suit == trump_suit end)

    cond do
      # Si uniquement des atouts, prendre le plus petit
      non_trumps == [] ->
        find_weakest(trumps, trump_suit)

      # Si uniquement des non-atouts, prendre le plus petit
      trumps == [] ->
        find_weakest(non_trumps, trump_suit)

      # Mix atout/non-atout : préférer défausser un non-atout
      true ->
        find_weakest(non_trumps, trump_suit)
    end
  end

  # Trouve la carte la plus faible dans une liste
  defp find_weakest(cards, trump_suit) do
    Enum.min_by(cards, fn card -> Card.strength(card, trump_suit) end)
  end
end
