defmodule Coinchette.Bots.Strategy do
  @moduledoc """
  Behaviour pour les stratégies de bot.

  Une stratégie détermine quelle carte jouer parmi les cartes légales
  selon les règles FFB.
  """

  alias Coinchette.Games.{Card, Player, Trick}

  @doc """
  Choisit une carte à jouer parmi les cartes valides.

  ## Paramètres
    * `player` - Le joueur bot
    * `trick` - Le pli en cours
    * `trump_suit` - La couleur d'atout
    * `valid_cards` - Liste des cartes légales (selon Rules.valid_cards)

  ## Retour
    * `Card.t()` - La carte choisie

  ## Exemples

      iex> choose_card(player, trick, :hearts, valid_cards)
      %Card{suit: :hearts, rank: :seven}
  """
  @callback choose_card(
              player :: Player.t(),
              trick :: Trick.t(),
              trump_suit :: Card.suit(),
              valid_cards :: list(Card.t())
            ) :: Card.t()
end
