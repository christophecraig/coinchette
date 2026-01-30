# Conventions de Code - Coinchette

## Principes Généraux

### Philosophie
- Clarté > Concision
- Explicite > Implicite
- Simple > Clever
- Fonctionnel > Impératif

### Règle d'or
Code écrit pour être lu par des humains, pas des machines.

## Style Elixir

### Formatage
- Utiliser mix format TOUJOURS avant commit
- Configuration .formatter.exs du projet fait foi
- Ligne max: 98 caractères (défaut formatter)

### Naming

#### Modules
✅ Bon
defmodule Coinchette.Games.Card do
defmodule Coinchette.Bots.Strategy.Medium do

❌ Mauvais
defmodule Coinchette.Card do  # Trop court, manque contexte
defmodule CardHelper do       # Suffixe Helper vague

#### Fonctions
✅ Bon - Verbes d'action
def deal_cards(deck)
def calculate_score(tricks, trump_suit)
def valid_moves(game_state, player_id)

❌ Mauvais
def cards(deck)              # Pas un verbe
def get_score(tricks, suit)  # get_ redondant en Elixir
def check_if_valid(state)    # check_if_ verbeux

#### Variables
✅ Bon - Noms descriptifs
current_player = game.players |> Enum.at(game.current_player_index)
trump_suit = :hearts
remaining_cards = Deck.remove(deck, played_cards)

❌ Mauvais
cp = game.players |> Enum.at(game.current_player_index)  # Abréviation
suit = :hearts  # Trop générique dans contexte trump
cards = Deck.remove(deck, played_cards)  # Ambigu

### Pattern Matching

✅ Bon - Pattern matching explicite
def play_card(%Game{state: :playing} = game, card) do
  # ...
end

def play_card(%Game{state: state}, _card) do
  {:error, "Cannot play card in state: #{state}"}
end

✅ Bon - Destructuration claire
def calculate_trick_winner([
  {first_card, first_player},
  {second_card, second_player},
  {third_card, third_player},
  {fourth_card, fourth_player}
], trump_suit) do
  # ...
end

❌ Mauvais - Trop clever
def play_card(%{state: s} = g, c) when s == :playing, do: # ...

### Pipelines

✅ Bon - Pipeline lisible
def valid_cards(hand, trick, trump_suit) do
  hand
  |> filter_by_suit(trick.suit)
  |> filter_by_trump_rules(trick, trump_suit)
  |> sort_by_value()
end

❌ Mauvais - Trop de transformations en une ligne
def valid_cards(hand, trick, trump) do
  hand |> Enum.filter(&(&1.suit == trick.suit)) |> Enum.map(&add_value/1) |> Enum.sort()
end

✅ Bon - Interrompre pipeline si trop long
def process_game_action(game, action) do
  game
  |> validate_action(action)
  |> case do
    {:ok, validated_game} ->
      validated_game
      |> apply_action(action)
      |> calculate_new_state()
      |> broadcast_update()

    {:error, reason} ->
      {:error, reason}
  end
end

### Guards

✅ Bon - Guards simples et clairs
def can_play_card?(card, hand) when is_list(hand) do
  card in hand
end

✅ Bon - Guards multiples séparées
def valid_bid?(bid) when is_integer(bid) and bid >= 80 and bid <= 160 do
  rem(bid, 10) == 0
end

❌ Mauvais - Guard trop complexe
def valid_bid?(b) when is_integer(b) and b >= 80 and b <= 160 and rem(b, 10) == 0, do: true

## Structure des Modules

### Template type
defmodule Coinchette.Games.Card do
  @moduledoc """
  Représente une carte à jouer.

  Une carte possède une valeur (7 à As) et une couleur (Pique, Cœur, Carreau, Trèfle).
  """

  # 1. Aliases et imports
  alias Coinchette.Games.{Suit, Rank}

  # 2. Types et structs
  @type t :: %__MODULE__{
    rank: Rank.t(),
    suit: Suit.t()
  }

  defstruct [:rank, :suit]

  # 3. Constantes publiques
  @all_ranks [:seven, :eight, :nine, :ten, :jack, :queen, :king, :ace]

  # 4. Fonctions publiques API
  @doc """
  Crée une nouvelle carte.

  ## Exemples

      iex> Card.new(:ace, :spades)
      %Card{rank: :ace, suit: :spades}
  """
  def new(rank, suit) do
    %__MODULE__{rank: rank, suit: suit}
  end

  @doc """
  Retourne la valeur en points de la carte selon le contexte.
  """
  def value(card, trump_suit, is_trump \\ false)

  def value(%{rank: :jack}, _trump, true), do: 20
  def value(%{rank: :nine}, _trump, true), do: 14
  # ... autres clauses

  # 5. Fonctions privées
  defp compare_ranks(rank1, rank2) do
    # ...
  end
end

### Ordre dans module
1. @moduledoc
2. use / import / alias / require
3. @type et defstruct
4. @constantes
5. Fonctions publiques (def)
6. Fonctions privées (defp)

## Contexts Pattern

✅ Bon - Context comme frontière claire
defmodule Coinchette.Games do
  @moduledoc """
  Context pour toute la logique métier des parties de belote/coinche.
  """

  alias Coinchette.Games.{Game, Card, Player}
  alias Coinchette.Repo

  # API publique uniquement
  def create_game(params), do: # ...
  def deal_cards(game_id), do: # ...
  def play_card(game_id, player_id, card), do: # ...

  # Pas d'accès direct aux schemas depuis l'extérieur
end

❌ Mauvais - Logique métier dans contrôleur
defmodule CoinchettWeb.GameController do
  def play_card(conn, %{"card_id" => card_id}) do
    game = Repo.get!(Game, conn.assigns.game_id)
    card = Enum.find(game.current_player.hand, & &1.id == card_id)
    
    # ❌ Logique métier ici !
    if Card.valid?(card, game.trick, game.trump) do
      # ...
    end
  end
end

## Tests

### Organisation fichiers
test/
├── coinchette/
│   ├── games/
│   │   ├── card_test.exs
│   │   ├── game_test.exs
│   │   └── rules/
│   │       ├── belote_test.exs
│   │       └── coinche_test.exs
│   └── bots/
│       └── strategy_test.exs
└── coinchette_web/
    └── live/
        └── game_live_test.exs

### Style tests
defmodule Coinchette.Games.CardTest do
  use Coinchette.DataCase, async: true

  alias Coinchette.Games.Card

  describe "new/2" do
    test "creates a card with rank and suit" do
      card = Card.new(:ace, :spades)

      assert card.rank == :ace
      assert card.suit == :spades
    end
  end

  describe "value/3" do
    test "returns 20 for jack of trumps" do
      card = Card.new(:jack, :hearts)

      assert Card.value(card, :hearts, true) == 20
    end

    test "returns 2 for jack of non-trumps" do
      card = Card.new(:jack, :hearts)

      assert Card.value(card, :spades, false) == 2
    end
  end

  describe "valid_move?/3" do
    setup do
      game_state = build(:game_state, trump: :hearts)
      {:ok, game: game_state}
    end

    test "allows playing trump when no cards of led suit", %{game: game} do
      hand = [Card.new(:jack, :hearts)]
      led_card = Card.new(:ace, :spades)

      assert Card.valid_move?(hd(hand), hand, led_card, game.trump)
    end
  end
end

### Règles tests
- 1 describe par fonction publique
- Nom de test = phrase complète
- Arrange / Act / Assert séparés visuellement
- Setup pour state partagé
- Pas de logique complexe dans tests
- async: true par défaut (sauf DB writes)

## Documentation

### @moduledoc
✅ Bon
@moduledoc """
Gère la logique métier des parties de belote et coinche.

Ce module expose les fonctions publiques pour créer, gérer et jouer
des parties. Il orchestre les différents sous-modules (Card, Deck, Rules, etc.)
et maintient la cohérence de l'état du jeu.
"""

❌ Mauvais
@moduledoc """
Module pour les jeux.
"""

### @doc
✅ Bon
@doc """
Joue une carte dans le pli en cours.

Valide que le coup est légal selon les règles de la belote, met à jour
l'état du jeu et retourne le nouveau state.

## Paramètres

  * `game` - État actuel de la partie
  * `player_id` - ID du joueur jouant la carte
  * `card` - Carte à jouer

## Retour

  * `{:ok, updated_game}` si le coup est valide
  * `{:error, reason}` si le coup est invalide

## Exemples

    iex> game = %Game{state: :playing, current_player: player1.id}
    iex> card = %Card{rank: :ace, suit: :spades}
    iex> Games.play_card(game, player1.id, card)
    {:ok, %Game{...}}

## Voir aussi

  * `valid_moves/2` - Pour obtenir la liste des coups légaux
  * `Coinchette.Games.Rules.Belote` - Pour les règles de validation
"""
def play_card(game, player_id, card) do
  # ...
end

❌ Pas assez documenté pour fonction critique
@doc "Plays a card"
def play_card(game, player_id, card), do: # ...

✅ OK pour fonction triviale
@doc "Returns player's current hand"
def get_hand(player), do: player.hand

### Commentaires inline
✅ Bon - Explique POURQUOI
def calculate_score(tricks, trump_suit) do
  base_score = sum_trick_values(tricks)
  
  # Ajouter le bonus de "dix de der" (10 points pour dernier pli)
  # Règle FFB officielle
  score_with_bonus = base_score + 10
  
  score_with_bonus
end

❌ Mauvais - Explique CE QUE fait le code (déjà visible)
def calculate_score(tricks, trump_suit) do
  # Calculer le score de base
  base_score = sum_trick_values(tricks)
  
  # Ajouter 10
  score_with_bonus = base_score + 10
  
  # Retourner le score
  score_with_bonus
end

✅ Bon - Cas limite documenté
def deal_cards(deck) do
  # La distribution FFB se fait en 2 tours : 3 puis 2 cartes
  # Impossible à faire avec Enum.chunk_every/2
  {first_round, remaining} = Enum.split(deck, 12)
  {second_round, talon} = Enum.split(remaining, 8)
  
  {first_round, second_round, talon}
end

## Git & Commits

### Messages de commit
Format:
<type>: <subject>

[body optionnel]

[footer optionnel]

Exemple:
feat: Add card validation logic for belote rules

Implements FFB official rules for:
- Following suit obligation
- Trump playing requirements
- Partner overtrumping rules

Closes #12

Types autorisés:
- feat: Nouvelle fonctionnalité
- fix: Correction de bug
- docs: Documentation uniquement
- style: Formatage (pas de changement de code)
- refactor: Refactorisation
- test: Ajout/modification tests
- chore: Tâches maintenance (deps, config, etc.)

### Branches
main              # Production-ready code
├── develop       # Integration branch
    ├── feat/game-logic-implementation
    ├── feat/bot-easy-difficulty
    ├── fix/card-validation-bug
    └── refactor/game-state-structure

### Pull Requests
- Titre explicite
- Description: Quoi, Pourquoi, Comment
- Lien vers issue si applicable
- Screenshots si UI
- Checklist:
  - [ ] Tests passent
  - [ ] Documentation à jour
  - [ ] Pas de warnings Credo
  - [ ] Testé localement

## Erreurs Communes à Éviter

### ❌ Mutation simulée
❌ Mauvais (penser impératif)
def add_card_to_hand(player, card) do
  new_hand = player.hand ++ [card]
  player = %{player | hand: new_hand}
  player
end

✅ Bon (penser fonctionnel)
def add_card_to_hand(player, card) do
  %{player | hand: player.hand ++ [card]}
end

### ❌ Ignorer résultats
❌ Mauvais
def create_game(params) do
  Repo.insert(%Game{})  # Ignore {:ok, game} ou {:error, changeset}
  # ...
end

✅ Bon
def create_game(params) do
  case Repo.insert(%Game{}) do
    {:ok, game} -> process_game(game)
    {:error, changeset} -> {:error, changeset}
  end
end

✅ Ou avec with
def create_game(params) do
  with {:ok, game} <- Repo.insert(%Game{}),
       {:ok, game} <- deal_initial_cards(game) do
    {:ok, game}
  end
end

## LiveView Spécifiques

### Naming events
✅ Bon - Verbes d'action
def handle_event("play_card", %{"card_id" => id}, socket)
def handle_event("start_game", _params, socket)
def handle_event("send_message", %{"text" => text}, socket)

❌ Mauvais
def handle_event("card", %{"id" => id}, socket)
def handle_event("click", _params, socket)

### Assigns
✅ Bon - Assigns minimaux
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:game_id, nil)
   |> assign(:current_user_id, nil)}
end

# Recharger depuis DB si besoin
def handle_event("play_card", params, socket) do
  game = Games.get_game!(socket.assigns.game_id)
  # ...
end

❌ Mauvais - Tout en assigns
def mount(_params, _session, socket) do
  game = Games.get_game!(id)
  
  {:ok,
   socket
   |> assign(:game, game)
   |> assign(:players, game.players)
   |> assign(:current_trick, game.current_trick)
   |> assign(:scores, game.scores)
   # ... Duplication de data !
   }
end

## Outils

### Obligatoires avant commit
mix format
mix compile --warnings-as-errors
mix test

### Recommandés
mix credo --strict
mix dialyzer  # Si temps acceptable

### Configuration Credo .credo.exs
%{
  configs: [
    %{
      name: "default",
      strict: true,
      checks: [
        {Credo.Check.Readability.ModuleDoc, []},
        {Credo.Check.Readability.MaxLineLength, [max_length: 98]},
      ]
    }
  ]
}

---

Version: 1.0
Dernière mise à jour: 30/01/2026
Validé par: Christophe Craig
