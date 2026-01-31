defmodule Coinchette.Bots do
  @moduledoc """
  Système de bots pour le mode solo de Coinchette.

  ## Utilisation

  Pour faire jouer un bot dans une partie :

      game = Game.new(:hearts) |> Game.deal_cards()
      {:ok, updated_game} = Game.play_bot_turn(game, Coinchette.Bots.Basic)

  ## Stratégies disponibles

  ### Basic
  Stratégie simple et conservative :
  - Joue toujours la plus petite carte valide
  - Préfère défausser des non-atouts quand possible
  - Respecte strictement les règles FFB

  ## Créer une stratégie personnalisée

  Implémentez le behaviour `Coinchette.Bots.Strategy` :

      defmodule MyBot do
        @behaviour Coinchette.Bots.Strategy

        @impl true
        def choose_card(player, trick, trump_suit, valid_cards) do
          # Votre logique ici
          hd(valid_cards)
        end
      end

  Puis utilisez-le :

      Game.play_bot_turn(game, MyBot)

  ## Règles importantes

  - Le bot reçoit toujours uniquement des cartes **valides** selon les règles FFB
  - La validation est faite par `Coinchette.Games.Rules.valid_cards/4`
  - Le bot doit simplement choisir parmi ces cartes valides
  - Impossible de tricher : les règles sont vérifiées avant le jeu

  ## Prochaines évolutions

  - Stratégies Easy/Medium/Hard avec différents niveaux d'IA
  - Système de mémoire (cartes jouées)
  - Calcul de probabilités
  - Comptage de cartes
  """

  alias Coinchette.Bots.Basic

  @doc """
  Retourne la stratégie par défaut (Basic).
  """
  def default_strategy, do: Basic
end
