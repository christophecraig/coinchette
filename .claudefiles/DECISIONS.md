# Décisions Architecturales - Coinchette

## ADR-001: Choix du Stack Technique

**Date**: 2024-01-XX
**Statut**: ✅ Accepté
**Décideurs**: [Nom]

### Contexte
Application de belote/coinche en ligne nécessitant:
- Temps réel (jeu multijoueur synchrone)
- Scalabilité (plusieurs parties simultanées)
- Logique métier complexe (règles FFB)
- Interface réactive

### Décision
Stack choisi:
- **Backend**: Elixir + Phoenix
- **Frontend**: Phoenix LiveView
- **Base de données**: PostgreSQL
- **Temps réel**: Phoenix PubSub + Channels

### Justification

#### Elixir/Phoenix
✅ Concurrence native (BEAM/OTP) = parfait pour multijoueur
✅ Fault-tolerance (supervision trees) = parties isolées
✅ Pattern matching = code règles élégant
✅ Immutabilité = game state sans bugs de mutation
✅ Performance temps réel excellente

Alternatives considérées:
- ❌ Node.js: Moins robuste pour fault-tolerance
- ❌ Ruby on Rails: Moins performant temps réel
- ❌ Go: Boilerplate plus lourd pour logique métier

#### LiveView vs React/Vue
✅ Pas de duplication logique client/serveur
✅ State management simplifié (côté serveur)
✅ Temps réel natif sans config complexe
✅ SEO-friendly par défaut
✅ Moins de JavaScript à maintenir

Alternatives considérées:
- ❌ React + Phoenix API: Duplication validation, state management complexe
- ❌ Vue + Phoenix API: Idem React
- ⚠️ Compromis: Pas de Progressive Web App offline (acceptable pour jeu multijoueur)

#### PostgreSQL
✅ Robustesse éprouvée
✅ JSONB pour game state flexible
✅ Transactions ACID (paris, scores)
✅ Full-text search (futur: chat, usernames)

Alternatives considérées:
- ❌ MongoDB: Pas de transactions multi-documents fiables
- ❌ Redis seul: Pas de persistance garantie

### Conséquences
✅ Développement rapide (LiveView = moins de code)
✅ Maintenance facilitée (un seul langage dominant)
✅ Performance temps réel native
⚠️ Courbe d'apprentissage Elixir pour nouveaux devs
⚠️ Écosystème LiveView plus jeune que React

### Références
- https://hexdocs.pm/phoenix_live_view/
- https://elixir-lang.org/getting-started/
- Retours projets similaires: [liens si dispos]

---

## ADR-002: Architecture du Game State

**Date**: 2024-01-XX
**Statut**: ✅ Accepté

### Contexte
Besoin de gérer l'état d'une partie de belote/coinche:
- État mutable complexe (tours, plis, scores)
- Validation stricte des coups (règles FFB)
- Historique pour replay/undo
- Synchronisation multi-joueurs

### Décision
Game state comme **struct immutable**:

```elixir
defmodule Coinchette.Games.Game do
  defstruct [
    :id,
    :players,
    :state,
    :current_trick,
    :tricks_won,
    :scores,
    :trump_suit,
    :contract,
    :phase
  ]
end

# Pattern immutabilité
def play_card(game, player_id, card) do
  with {:ok, validated_game} <- validate_move(game, player_id, card),
       {:ok, updated_game} <- apply_move(validated_game, card) do
    broadcast_update(updated_game)
    {:ok, updated_game}
  end
end
```

### Justification
#### Pourquoi Struct Immutable?
- Pas de side-effects cachés
- Rollback facile (garder état précédent)
- Tests déterministes
- Debugging simplifié (état = snapshot)
- Pattern matching puissant

Exemple concret:
```elixir
def calculate_score(%Game{state: :round_finished} = game) do
  # Pattern matching garantit bon état
  # ...
end
```

### Pourquoi pas GenServer pour Game State?
❌ Over-engineering pour MVP
❌ State mutable dans process = bugs potentiels
❌ Testing plus complexe
✅ Peut wrapper struct dans GenServer plus tard si besoin coordination

### Où Persister?

PostgreSQL: État complet après chaque coup
PubSub: Broadcast changements temps réel
ETS: Cache session (optionnel V2)

### Conséquences
✅ Code testable facilement (pure functions)
✅ Bugs mutation impossibles
✅ Replay/audit trail gratuit
⚠️ Sérialisation complète à chaque coup (acceptable perf)
🚧 TODO: Implémenter versioning schema si breaking changes


---

## ADR-003: Gestion du Temps Réel

**Date**: 2024-01-XX
**Statut**: ✅ Accepté

### Contexte
Multijoueurs = besoin synchronisation temps réel:
- Jouer carte visible instantanément pour tous
- Gestion déconnexions/reconnexions
- Latence acceptable (<200ms)

### Décision
**Phoenix Channels** + **PubSub** pour broadcast:

```elixir
# Channel par partie
defmodule CoinchettaWeb.GameChannel do
  use Phoenix.Channel

  def join("game:" <> game_id, _params, socket) do
    game = Games.get_game!(game_id)
    {:ok, game, assign(socket, :game_id, game_id)}
  end

  def handle_in("play_card", %{"card" => card}, socket) do
    case Games.play_card(socket.assigns.game_id, card) do
      {:ok, updated_game} ->
        broadcast!(socket, "game_update", updated_game)
        {:reply, :ok, socket}
      {:error, reason} ->
        {:reply, {:error, reason}, socket}
    end
  end
end
```

### Justification

#### Pourquoi Channels vs Alternatives?
✅ Bi-directionnel natif
✅ Intégré Phoenix (pas lib externe)
✅ Reconnexion automatique
✅ Authentification intégrée

### Alternatives considérées:
❌ WebSockets raw: Boilerplate, pas de reconnexion auto
❌ Server-Sent Events: Unidirectionnel seulement
❌ Polling HTTP: Latence++, ressources++

### Architecture PubSub
Player A joue carte
     ↓
GameChannel reçoit event
     ↓
Games.play_card/2 (validation + update)
     ↓
PubSub broadcast "game:123"
     ↓
Tous channels game:123 reçoivent
     ↓
LiveView.send_update pour chaque joueur

### Conséquences
✅ Latence <100ms locale, <200ms internet
✅ Scalabilité horizontale (PubSub distribué)
✅ Code simple (pas framework JS complexe)
⚠️ Gestion déconnexion manuelle requise
🚧 TODO: Heartbeat pour détecter zombies


---

## ADR-004: Stratégie de Tests

**Date**: 2024-01-XX
**Statut**: ✅ Accepté

### Contexte
Logique métier complexe (règles FFB) = bugs coûteux.
Besoin garantir:
- Respect règles officielles
- Non-régression
- Confiance refactoring

### Décision

#### Pyramide de Tests

         /\
        /E2E\  (5% - smoke tests critiques)
       /------\
      /  Integ \ (25% - flows complets)
     /----------\
    /   Unit     \ (70% - logique pure)
   /--------------\

#### Par Couche

**1. Unit Tests (70%)** - Logique pure
```elixir
# test/coinchette/games/rules_test.exs
describe "validate_card/3" do
  test "must follow suit if possible" do
    game = game_fixture(trump: :hearts)
    hand = [card(:hearts, :ace), card(:spades, :king)]
    led_suit = :hearts
    
    assert Rules.validate_card(game, hand, card(:spades, :king)) == 
      {:error, :must_follow_suit}
  end
end
```

**2. Integration Tests (25%)** - Flows complets
```elixir
# test/coinchette/games_test.exs
test "complete bidding and playing round" do
  {:ok, game} = Games.create_game(players: 4)
  {:ok, game} = Games.bid(game, player1, {:coinche, :hearts, 120})
  {:ok, game} = Games.play_card(game, player1, card(:hearts, :ace))
  # ... assertions état final
end
```

**3. E2E Tests (5%)** - Smoke tests critiques
```elixir
# test/coinchetta_web/live/game_live_test.exs
test "can play complete game via UI", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/games/new")
  view |> element("button", "Créer") |> render_click()
  # ... simulation partie complète
  assert view |> element(".winner") |> render() =~ "Équipe 1"
end
```

#### Property-Based Testing (règles critiques)

```elixir
# test/coinchette/games/rules_property_test.exs
use ExUnitProperties

property "points calculated always sum to 162" do
  check all game <- game_generator() do
    teams_points = Rules.calculate_points(game)
    assert Enum.sum(teams_points) == 162
  end
end
```

### Justification

#### Pourquoi cette répartition?
✅ Unit = feedback rapide, isolation bugs
✅ Integration = validation flows réels
✅ E2E minimal = coût maintenance élevé
✅ Property = garanties mathématiques règles

#### Outils
- **ExUnit**: Framework natif Elixir
- **StreamData**: Property-based testing
- **Wallaby**: E2E (headless browser)
- **Mox**: Mocking (PubSub, DB en tests)

### Conséquences
✅ Confiance refactoring
✅ Documentation vivante (tests = exemples)
✅ Régression impossible si CI bloque
⚠️ Temps écriture tests ~40% du dev (acceptable)
🚧 TODO: CI/CD avec coverage >85%

---

## ADR-005: Gestion des Bots (IA)

**Date**: 2024-01-XX
**Statut**: 🚧 En cours de validation

### Contexte
Besoin bots IA pour:
- Parties solo (entraînement)
- Remplacer joueurs déconnectés
- Testing automatisé

Contraintes:
- Respecter règles FFB
- Décisions <500ms (pas ralentir partie)
- Niveaux difficulté (easy/medium/hard)

### Décision

#### Architecture Modulaire

```elixir
defmodule Coinchette.Bots.Strategy do
  @callback choose_bid(game, hand) :: bid
  @callback choose_card(game, hand, legal_cards) :: card
end

defmodule Coinchette.Bots.Easy do
  @behaviour Coinchette.Bots.Strategy
  # Implémentation basique
end

defmodule Coinchette.Bots.Medium do
  @behaviour Coinchette.Bots.Strategy
  # Heuristiques avancées
end
```

#### Niveaux Difficulté

**Easy (MVP)**
- Coups aléatoires parmi légaux
- Pas de stratégie
- Temps réponse: <50ms

```elixir
def choose_card(_game, _hand, legal_cards) do
  Enum.random(legal_cards)
end
```

**Medium (Post-MVP)**
- Heuristiques simples:
  * Jouer atouts forts si partenaire maître
  * Défausser faibles si perdu
  * Couper si pas la couleur
- Temps: <200ms

**Hard (V2)**
- Simulations Monte Carlo (100 parties)
- Mémorisation cartes jouées
- Calcul probabilités mains adverses
- Temps: <500ms

### Alternatives Considérées

#### Alternative 1: IA Machine Learning
❌ Rejeté pour MVP
- Nécessite dataset parties (pas dispo au début)
- Over-engineering
- Pas de garantie respect règles

#### Alternative 2: API externe (bot cloud)
❌ Rejeté
- Latence réseau
- Dépendance service externe
- Coût

### Conséquences
✅ Parties solo possibles (entraînement)
✅ Remplacement déconnexions automatique
✅ Stratégies modulaires (swap facile)
⚠️ Bot Easy très basique (acceptable MVP)
🚧 TODO: Implémenter Medium/Hard post-MVP

---

## Template pour Nouvelles ADR

```markdown
## ADR-XXX: [Titre]

**Date**: YYYY-MM-DD
**Statut**: 🚧 Proposition | ✅ Accepté | ❌ Rejeté | ⚠️ Deprecated
**Décideurs**: [Noms]

### Contexte
[Décrire le problème / le besoin]

### Décision
[Décrire la solution choisie]

### Justification
[Pourquoi cette solution ?]

### Alternatives Considérées
[Autres options évaluées et pourquoi rejetées]

### Conséquences
✅ Avantages
⚠️ Inconvénients / Trade-offs
🚧 Actions requises

### Références
[Liens, docs, discussions]
```

---

## Index des ADR

| # | Titre | Statut | Date |
|---|-------|--------|------|
| 001 | Stack Technique | ✅ Accepté | 2026-01-30 |
| 002 | Architecture Game State | ✅ Accepté | 2026-01-30 |
| 003 | Gestion Temps Réel | ✅ Accepté | 2026-01-30 |
| 004 | Stratégie Tests | ✅ Accepté | 2026-01-30 |
| 005 | Gestion Bots | 🚧 En cours | 2026-01-30 |

---

**Version**: 1.0
**Maintenu par**: Christophe Craig & Claude
**Dernière revue**: 30/01/2026
