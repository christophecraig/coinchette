# Coinchette

**Application web de belote et coinche en ligne**

Jouez à la belote ou la coinche seul contre des bots ou avec vos amis en ligne.

## Stack Technique

- **Backend**: Elixir 1.19+ / Phoenix 1.8+
- **Frontend**: Phoenix LiveView
- **Base de données**: PostgreSQL 18+
- **Temps réel**: Phoenix Channels + PubSub

## Prérequis

- Elixir 1.19+ (via asdf recommandé)
- Erlang/OTP 27+
- PostgreSQL 18+
- Node.js (pour assets)

## Installation

```bash
# 1. Installer les dépendances
mix deps.get

# 2. Créer et migrer la base de données
mix ecto.setup

# 3. Installer les dépendances JavaScript
cd assets && npm install

# 4. Démarrer le serveur Phoenix
mix phx.server
```

Visitez [`localhost:4000`](http://localhost:4000) dans votre navigateur.

## Développement

```bash
# Lancer les tests
mix test

# Lancer les tests avec coverage
mix test --cover

# Lancer le serveur en mode interactif
iex -S mix phx.server

# Formater le code
mix format

# Linter (après installation de Credo)
mix credo --strict
```

## Architecture

Voir la documentation complète dans `.claudefiles/`:
- `PROJECT.md` : Vision et objectifs
- `STACK.md` : Détails techniques
- `RULES.md` : Règles officielles FFB
- `TASKS.md` : Backlog et tâches
- `CONVENTIONS.md` : Standards de code

## Roadmap

### Phase 1 - MVP (en cours)
- ✅ Setup infrastructure
- [ ] Moteur de jeu belote/coinche
- [ ] Interface web LiveView
- [ ] Bots IA (facile/moyen/difficile)
- [ ] Mode multijoueur privé
- [ ] Système d'amis et chat

### Phase 2 - Mobile
- [ ] API GraphQL
- [ ] Applications iOS et Android

## Contribuer

1. Lire `CONVENTIONS.md` pour les standards de code
2. Approche TDD stricte (tests avant code)
3. Respecter les règles FFB (`RULES.md`)
4. Commits atomiques et descriptifs

## License

Propriétaire - Christophe Craig

---

Version: 0.1.0 (MVP en développement)
