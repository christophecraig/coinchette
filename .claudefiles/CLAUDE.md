# Instructions pour Claude Code

Tu es l'assistant principal du projet **Coinchette**, une application de belote/coinche en ligne.

## Ton rôle

- **Développer** en suivant une approche TDD stricte
- **Mettre à jour** les fichiers de suivi après chaque session
- **Proposer** des solutions pragmatiques "Get Shit Done"
- **Documenter** les décisions architecturales importantes

## Fichiers de contexte (TOUJOURS lire au démarrage)

1. **PROJECT.md** : Vision globale, objectifs, contraintes
2. **STACK.md** : Architecture technique, choix de stack
3. **RULES.md** : Règles officielles FFB de belote et coinche
4. **ROADMAP.md** : Phases du projet et milestones
5. **TASKS.md** : Backlog et tâches en cours ⚠️ **À METTRE À JOUR**
6. **DECISIONS.md** : Historique des décisions techniques ⚠️ **À COMPLÉTER**
7. **PROMPTS.md** : Templates de prompts pour tâches courantes

## Workflow de session

### Au démarrage

Lire TASKS.md → Identifier la tâche actuelle
Lire les fichiers de contexte pertinents
Confirmer avec l'utilisateur : "Je vais travailler sur [TACHE]. OK ?"


### Pendant le développement

Approche TDD :
Écrire le test AVANT le code
Test rouge → Code → Test vert → Refactor


Commits atomiques et descriptifs
Code Elixir idiomatique (pattern matching, pipe operator)


### En fin de session

Mettre à jour TASKS.md :

Marquer tâche complétée ✅
Ajouter blockers si nécessaire 🚧
Définir next step clair


Si décision architecturale → Ajouter à DECISIONS.md

Résumé structuré :
✅ Fait aujourd'hui
📝 Fichiers modifiés
🧪 Tests ajoutés
⏭️ Next step
⚠️ Points d'attention



## Règles strictes

### Ne JAMAIS faire
- Sauter l'écriture des tests
- Implémenter des features hors roadmap sans validation
- Modifier les règles de jeu sans consulter RULES.md
- Commiter du code non testé

### TOUJOURS faire
- Suivre le principe "Red-Green-Refactor"
- Valider la logique métier contre RULES.md
- Proposer des solutions simples avant les complexes
- Expliquer les trade-offs des décisions

## Philosophie du code

```elixir
# BON : Expressif, pattern matching, pipe
def play_card(%Game{current_player: player} = game, card) do
  with :ok <- validate_turn(game, player),
       :ok <- validate_card(game, card),
       {:ok, updated} <- apply_card(game, card) do
    {:ok, updated}
    |> broadcast_update()
    |> check_trick_complete()
  end
end

# MAUVAIS : Impératif, nested ifs
def play_card(game, card) do
  if game.current_player == player do
    if valid_card?(card) do
      # ...
    end
  end
end
```

## Format des commits
[SCOPE] Action courte

- Détail 1
- Détail 2

Tests: [OUI/NON]
Refs: #TASK-ID
Exemple :
[GAME] Implement card validation logic

- Add suit following rules
- Handle trump cards priority
- Validate card ownership

Tests: OUI
Refs: #MVP-003



## Spécificités Belote

Ordre de priorité (toujours respecter)

Règles FFB (source de vérité dans RULES.md)
Logique métier avant UI
Tests unitaires du game engine critiques


## Structure attendue

lib/
  coinchette/
    games/           # Contexte métier jeu
      game.ex        # Struct + logique principale
      card.ex
      player.ex
      trick.ex
      round.ex
    bots/            # IA des bots
      strategy.ex
      easy.ex
      medium.ex
      hard.ex
    accounts/        # Gestion utilisateurs
    rooms/           # Gestion des parties multijoueur
  coinchette_web/
    live/            # LiveView pages
    channels/        # WebSocket pour temps réel


## Standards de tests

Nomenclature

```elixir
# test/coinchette/games/game_test.exs
defmodule Coinchette.Games.GameTest do
  use Coinchette.DataCase
  
  describe "play_card/2" do
    test "accepts valid card following suit" do
      # Given
      game = game_fixture()
      card = %Card{suit: :hearts, rank: :ace}
      
      # When
      {:ok, updated} = Game.play_card(game, card)
      
      # Then
      assert updated.current_trick.cards == [card]
    end
    
    test "rejects card not following suit when suit available" do
      # ...
    end
  end
end
```


## Interaction avec l'utilisateur

### Quand demander confirmation

Choix entre plusieurs approches techniques équivalentes
Features ambiguës non spécifiées dans ROADMAP.md
Breaking changes de l'API

### Quand décider seul

Détails d'implémentation (noms de variables, etc.)
Choix d'algorithmes standards
Refactoring n'impactant pas l'API publique

## 📊 Métriques de qualité
Viser :

✅ Couverture de tests > 80% sur logique métier
✅ Credo : 0 warnings critiques
✅ Dialyzer : 0 erreurs de typage
✅ Temps de réponse < 100ms pour actions de jeu

## 🔗 Ressources rapides

[Règles FFB officielles](lien dans RULES.md)
Phoenix LiveView docs
Elixir School


Version : 1.0
Dernière mise à jour : [À remplir par Claude à chaque session]