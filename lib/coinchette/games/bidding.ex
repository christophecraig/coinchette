defmodule Coinchette.Games.Bidding do
  @moduledoc """
  Gère la phase d'enchères de la belote classique selon les règles FFB.

  ## Déroulement

  ### Premier tour
  - Joueur à droite du donneur commence
  - Options : `:take` (prendre la couleur proposée) ou `:pass`
  - Si quelqu'un prend → enchères terminées
  - Si tous passent → second tour

  ### Second tour
  - Même ordre de jeu
  - Options : `{:choose, suit}` (choisir une autre couleur) ou `:pass`
  - Couleur proposée interdite
  - Si quelqu'un choisit → enchères terminées
  - Si tous passent → enchères échouent, redistribution

  ## Exemples

      iex> proposed_card = %Card{suit: :hearts, rank: :seven}
      iex> bidding = Bidding.new(proposed_card, dealer_position: 0)
      iex> {:ok, updated} = Bidding.bid(bidding, :take)
      iex> updated.trump_suit
      :hearts
  """

  alias Coinchette.Games.Card

  @type status :: :in_progress | :completed | :failed
  @type action :: :take | :pass | {:choose, Card.suit()}

  @type t :: %__MODULE__{
          proposed_trump: Card.suit(),
          dealer_position: 0..3,
          current_bidder: 0..3,
          round: 1 | 2,
          taker: 0..3 | nil,
          trump_suit: Card.suit() | nil,
          status: status()
        }

  defstruct [
    :proposed_trump,
    :dealer_position,
    :current_bidder,
    :taker,
    :trump_suit,
    round: 1,
    status: :in_progress
  ]

  @doc """
  Crée une nouvelle phase d'enchères.

  ## Paramètres

    * `proposed_card` - La carte retournée du talon
    * `dealer_position` - Position du donneur (0-3)

  ## Exemples

      iex> card = %Card{suit: :hearts, rank: :seven}
      iex> bidding = Bidding.new(card, dealer_position: 0)
      iex> bidding.proposed_trump
      :hearts
      iex> bidding.current_bidder
      1
  """
  def new(%Card{suit: suit}, dealer_position: dealer_position)
      when dealer_position in 0..3 do
    %__MODULE__{
      proposed_trump: suit,
      dealer_position: dealer_position,
      current_bidder: next_position(dealer_position),
      taker: nil,
      trump_suit: nil,
      round: 1,
      status: :in_progress
    }
  end

  @doc """
  Effectue une enchère.

  ## Paramètres

    * `bidding` - État actuel des enchères
    * `action` - Action du joueur : `:take`, `:pass`, ou `{:choose, suit}`

  ## Retour

    * `{:ok, updated_bidding}` si l'action est valide
    * `{:error, reason}` sinon

  ## Exemples

      # Premier tour - Prendre
      iex> bidding = Bidding.new(%Card{suit: :hearts, rank: :seven}, dealer_position: 0)
      iex> {:ok, updated} = Bidding.bid(bidding, :take)
      iex> updated.status
      :completed

      # Premier tour - Passer
      iex> bidding = Bidding.new(%Card{suit: :hearts, rank: :seven}, dealer_position: 0)
      iex> {:ok, updated} = Bidding.bid(bidding, :pass)
      iex> updated.current_bidder
      2

      # Second tour - Choisir autre couleur
      iex> bidding = %Bidding{round: 2, proposed_trump: :hearts, current_bidder: 1}
      iex> {:ok, updated} = Bidding.bid(bidding, {:choose, :spades})
      iex> updated.trump_suit
      :spades
  """
  def bid(%__MODULE__{status: :completed}, _action) do
    {:error, :bidding_already_completed}
  end

  def bid(%__MODULE__{status: :failed}, _action) do
    {:error, :bidding_failed}
  end

  def bid(%__MODULE__{round: 1} = bidding, :take) do
    {:ok,
     %{bidding |
       taker: bidding.current_bidder,
       trump_suit: bidding.proposed_trump,
       status: :completed
     }}
  end

  def bid(%__MODULE__{round: 1} = bidding, :pass) do
    next_bidder = next_position(bidding.current_bidder)

    # Si on revient au donneur (après que tous aient passé), passer au round 2
    if next_bidder == next_position(bidding.dealer_position) do
      {:ok,
       %{bidding |
         round: 2,
         current_bidder: next_position(bidding.dealer_position)
       }}
    else
      {:ok, %{bidding | current_bidder: next_bidder}}
    end
  end

  def bid(%__MODULE__{round: 1}, {:choose, _suit}) do
    {:error, :must_take_or_pass_round_1}
  end

  def bid(%__MODULE__{round: 2}, :take) do
    {:error, :cannot_take_round_2}
  end

  def bid(%__MODULE__{round: 2, proposed_trump: proposed}, {:choose, suit})
      when suit == proposed do
    {:error, :cannot_choose_proposed_trump}
  end

  def bid(%__MODULE__{round: 2} = bidding, {:choose, suit})
      when suit in [:spades, :hearts, :diamonds, :clubs] do
    {:ok,
     %{bidding |
       taker: bidding.current_bidder,
       trump_suit: suit,
       status: :completed
     }}
  end

  def bid(%__MODULE__{round: 2}, {:choose, _invalid_suit}) do
    {:error, :invalid_suit}
  end

  def bid(%__MODULE__{round: 2} = bidding, :pass) do
    next_bidder = next_position(bidding.current_bidder)

    # Si on revient au donneur (après que tous aient passé au round 2), enchères échouent
    if next_bidder == next_position(bidding.dealer_position) do
      {:ok, %{bidding | status: :failed}}
    else
      {:ok, %{bidding | current_bidder: next_bidder}}
    end
  end

  @doc """
  Vérifie si les enchères sont terminées avec succès.

  ## Exemples

      iex> bidding = %Bidding{status: :completed}
      iex> Bidding.completed?(bidding)
      true

      iex> bidding = %Bidding{status: :in_progress}
      iex> Bidding.completed?(bidding)
      false
  """
  def completed?(%__MODULE__{status: :completed}), do: true
  def completed?(%__MODULE__{}), do: false

  @doc """
  Vérifie si les enchères ont échoué (tous ont passé).

  ## Exemples

      iex> bidding = %Bidding{status: :failed}
      iex> Bidding.failed?(bidding)
      true

      iex> bidding = %Bidding{status: :completed}
      iex> Bidding.failed?(bidding)
      false
  """
  def failed?(%__MODULE__{status: :failed}), do: true
  def failed?(%__MODULE__{}), do: false

  # Fonctions privées

  defp next_position(position) do
    rem(position + 1, 4)
  end
end
