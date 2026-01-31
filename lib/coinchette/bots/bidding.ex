defmodule Coinchette.Bots.Bidding do
  @moduledoc """
  Stratégie de bidding pour les bots en mode multijoueur.

  Implémente une stratégie simple mais efficace pour les enchères :
  - Premier tour : prend si la main contient >= 2 atouts dont au moins 1 fort
  - Second tour : choisit la couleur la plus forte (si score suffisant)

  ## Stratégie détaillée

  ### Premier tour (carte proposée)
  Prend si :
  - Au moins 2 atouts dans la main ET au moins 1 atout fort (V, 9, A, 10)
  - OU au moins 3 atouts (même faibles)

  ### Second tour (choix libre)
  - Évalue chaque couleur (sauf celle proposée)
  - Calcule un score basé sur : nombre de cartes + force totale
  - Choisit la couleur avec le meilleur score si >= seuil minimum
  - Sinon passe

  ## Exemples

      iex> hand = [Card.new(:jack, :hearts), Card.new(:nine, :hearts), ...]
      iex> Bidding.decide_bid(hand, :hearts, round: 1)
      :take

      iex> hand = [Card.new(:ace, :spades), Card.new(:ten, :spades), ...]
      iex> Bidding.decide_bid(hand, :hearts, round: 2)
      {:choose, :spades}
  """

  alias Coinchette.Games.Card

  # Seuil minimum pour prendre au second tour (score = count * 10 + total_strength)
  @min_score_round_2 50

  @doc """
  Décide de l'action à prendre pendant les enchères.

  ## Paramètres

    * `hand` - Liste des cartes dans la main du bot (5 cartes)
    * `proposed_trump` - Couleur proposée (carte retournée du talon)
    * `opts` - Options, doit contenir `round: 1` ou `round: 2`

  ## Retour

    * `:take` - Prendre la couleur proposée (round 1 uniquement)
    * `{:choose, suit}` - Choisir une couleur spécifique (round 2 uniquement)
    * `:pass` - Passer son tour

  ## Exemples

      # Round 1 - Main forte en atouts
      iex> hand = [Card.new(:jack, :hearts), Card.new(:nine, :hearts), ...]
      iex> Bidding.decide_bid(hand, :hearts, round: 1)
      :take

      # Round 1 - Main faible
      iex> hand = [Card.new(:seven, :hearts), Card.new(:eight, :spades), ...]
      iex> Bidding.decide_bid(hand, :hearts, round: 1)
      :pass

      # Round 2 - Main forte en piques
      iex> hand = [Card.new(:ace, :spades), Card.new(:ten, :spades), ...]
      iex> Bidding.decide_bid(hand, :hearts, round: 2)
      {:choose, :spades}
  """
  def decide_bid(hand, proposed_trump, opts) do
    round = Keyword.fetch!(opts, :round)

    case round do
      1 -> decide_round_1(hand, proposed_trump)
      2 -> decide_round_2(hand, proposed_trump)
    end
  end

  # Décision pour le premier tour (prendre ou passer la couleur proposée)
  defp decide_round_1(hand, proposed_trump) do
    trumps = Enum.filter(hand, fn card -> card.suit == proposed_trump end)
    trump_count = length(trumps)

    cond do
      # Pas assez d'atouts
      trump_count < 2 ->
        :pass

      # 3+ atouts : toujours prendre
      trump_count >= 3 ->
        :take

      # 2 atouts : vérifier qu'au moins 1 est fort
      trump_count == 2 ->
        if has_strong_trump?(trumps) do
          :take
        else
          :pass
        end
    end
  end

  # Décision pour le second tour (choisir une couleur ou passer)
  defp decide_round_2(hand, proposed_trump) do
    # Évaluer toutes les couleurs sauf celle proposée
    available_suits = [:spades, :hearts, :diamonds, :clubs] -- [proposed_trump]

    suit_scores =
      available_suits
      |> Enum.map(fn suit ->
        cards_in_suit = Enum.filter(hand, fn card -> card.suit == suit end)
        score = evaluate_suit_strength(cards_in_suit, suit)
        {suit, score}
      end)
      |> Enum.sort_by(fn {_suit, score} -> score end, :desc)

    case suit_scores do
      [{best_suit, score} | _] when score >= @min_score_round_2 ->
        {:choose, best_suit}

      _ ->
        :pass
    end
  end

  # Vérifie si la liste d'atouts contient au moins une carte forte
  defp has_strong_trump?(trumps) do
    Enum.any?(trumps, fn card ->
      card.rank in [:jack, :nine, :ace, :ten]
    end)
  end

  # Évalue la force d'une couleur pour le second tour
  # Score = (nombre de cartes * 10) + force totale des cartes
  defp evaluate_suit_strength(cards, suit) do
    count = length(cards)
    total_strength = Enum.sum(Enum.map(cards, fn card -> Card.strength(card, suit) end))

    # Formule : favorise les couleurs avec plusieurs cartes ET fortes
    count * 10 + total_strength
  end
end
