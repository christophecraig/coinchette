# Stack Technique - Coinchette

## Architecture Globale

Type: Monolithe Phoenix (MVP Phase 1)
Évolution: Extraction API future (Phase 2)

### Justification approche monolithe
- Équipe niveau débutant Elixir
- Pas de besoin immédiat d'apps mobiles
- Réduction complexité déploiement
- Time-to-market optimisé
- Phoenix LiveView = 90% des besoins couverts

## Technologies

### Backend
- Langage: Elixir 1.19+
- Framework: Phoenix 1.8+
- Base de données: PostgreSQL 18+
- Temps réel: Phoenix Channels + LiveView
- Tests: ExUnit + Wallaby (E2E)

### Frontend
- LiveView (pas de SPA JavaScript)
- TailwindCSS pour styling
- Alpine.js pour interactions JS légères (si nécessaire)
- Heroicons pour icônes

### Infrastructure
- Hosting: Render.com
- CI/CD: GitHub Actions
- Monitoring: Render metrics + Phoenix LiveDashboard
- Logs: Render logs natifs

## Structure de l'application
coinchette/
├── lib/
│   ├── coinchette/              # Contextes métier
│   │   ├── accounts/            # Gestion utilisateurs
│   │   │   ├── user.ex
│   │   │   └── user_token.ex
│   │   ├── games/               # Logique de jeu
│   │   │   ├── game.ex          # State machine principale
│   │   │   ├── card.ex
│   │   │   ├── deck.ex
│   │   │   ├── player.ex
│   │   │   ├── trick.ex
│   │   │   ├── round.ex
│   │   │   ├── score.ex
│   │   │   └── rules/
│   │   │       ├── belote.ex
│   │   │       └── coinche.ex
│   │   ├── bots/                # Intelligence artificielle
│   │   │   ├── bot.ex
│   │   │   ├── strategy.ex
│   │   │   ├── easy.ex
│   │   │   ├── medium.ex
│   │   │   └── hard.ex
│   │   ├── rooms/               # Gestion parties multi
│   │   │   ├── room.ex
│   │   │   ├── invitation.ex
│   │   │   └── room_server.ex   # GenServer
│   │   ├── friendships/         # Système d'amis
│   │   │   └── friendship.ex
│   │   ├── chat/                # Messages
│   │   │   └── message.ex
│   │   └── leaderboard/         # Classements
│   │       └── ranking.ex
│   ├── coinchette_web/          # Interface web
│   │   ├── channels/
│   │   │   └── room_channel.ex
│   │   ├── live/
│   │   │   ├── game_live/
│   │   │   │   ├── index.ex
│   │   │   │   ├── show.ex
│   │   │   │   └── components.ex
│   │   │   ├── room_live/
│   │   │   ├── friend_live/
│   │   │   ├── leaderboard_live/
│   │   │   └── history_live/
│   │   ├── components/
│   │   │   ├── core_components.ex
│   │   │   ├── card.ex
│   │   │   └── table.ex
│   │   └── controllers/
│   │       └── page_controller.ex
│   └── coinchette.ex
├── test/
│   ├── coinchette/
│   │   ├── games/               # Tests unitaires logique
│   │   └── bots/
│   ├── coinchette_web/
│   │   └── live/                # Tests d'intégration
│   └── support/
│       ├── fixtures.ex
│       └── factories.ex
├── priv/
│   ├── repo/
│   │   └── migrations/
│   └── static/
├── config/
└── .claudefiles/                # Documentation projet

## Schéma Base de Données (simplifié)
users
- id: uuid (PK)
- email: string (unique)
- username: string (unique)
- hashed_password: string
- confirmed_at: timestamp
- inserted_at: timestamp
- updated_at: timestamp

games
- id: uuid (PK)
- variant: enum (belote, coinche)
- mode: enum (solo, multi)
- status: enum (waiting, playing, finished)
- state: jsonb (state machine complet)
- winner_team: integer
- scores: jsonb
- started_at: timestamp
- finished_at: timestamp
- inserted_at: timestamp

game_players
- id: uuid (PK)
- game_id: uuid (FK)
- user_id: uuid (FK nullable si bot)
- position: integer (0-3)
- is_bot: boolean
- bot_difficulty: enum (easy, medium, hard)

friendships
- id: uuid (PK)
- user_id: uuid (FK)
- friend_id: uuid (FK)
- status: enum (pending, accepted, blocked)
- inserted_at: timestamp

messages
- id: uuid (PK)
- sender_id: uuid (FK)
- recipient_id: uuid (FK nullable)
- game_id: uuid (FK nullable)
- content: text
- read_at: timestamp
- inserted_at: timestamp

rankings
- id: uuid (PK)
- user_id: uuid (FK)
- variant: enum
- games_played: integer
- games_won: integer
- total_points: integer
- updated_at: timestamp


## Patterns et Conventions

### Contextes Elixir
- Un contexte = un domaine métier
- Pas de contextes qui s'appellent entre eux directement
- Communication via PubSub si nécessaire

### State Management Jeu
- Game state = struct Elixir pure (pas d'ETS, pas d'Agent)
- Persisté en JSONB dans PostgreSQL
- Rechargé à chaque action pour stateless
- Alternative: GenServer par partie si perf insuffisantes

### LiveView
- Composants fonctionnels réutilisables
- État minimal dans le socket
- Rechargement depuis DB fréquent acceptable (MVP)

### Temps réel
- Phoenix Channels pour sync multi-joueurs
- Presence pour suivi connexions
- PubSub pour notifications

## Décisions Techniques Clés

### Pourquoi pas de SPA React/Vue ?
- LiveView couvre 100% besoins MVP
- Moins de complexité frontend
- Pas besoin d'API REST pour commencer
- Meilleure SEO naturellement
- Déploiement simplifié

### Pourquoi PostgreSQL JSONB pour game state ?
- Flexibilité durant développement
- Pas de migrations fréquentes
- Suffisant pour volume MVP
- Requêtable si besoin analytics
- Migration vers tables normalisées possible plus tard

### Pourquoi pas Redis ?
- Pas de besoin de cache avancé pour MVP
- PostgreSQL suffit pour sessions
- Render.com PostgreSQL inclus gratuit
- Réduction coûts infrastructure

### Pourquoi GenServer optionnel ?
- Démarrer simple avec state stateless
- Ajouter GenServer si besoins perf constatés
- Évite complexité distribution OTP pour MVP

## Performance Targets MVP
- Temps réponse action jeu: < 200ms
- Temps chargement page: < 2s
- Support concurrent: 50 parties simultanées
- Latence temps réel: < 500ms

## Sécurité
- Authentification: phx.gen.auth
- CSRF protection: activée par défaut
- Rate limiting: Plug.RateLimit sur actions critiques
- Validation inputs: Ecto changesets
- Secrets: Variables d'environnement Render

## Monitoring MVP

- Phoenix LiveDashboard (metrics runtime)
- Render metrics natifs (CPU, RAM, requêtes)
- Logs applicatifs via Logger
- Pas d'APM externe pour MVP (Sentry en Phase 2)

## CI/CD

GitHub Actions workflow:
1. Install deps
2. Compile
3. Run tests (ExUnit)
4. Run Credo
5. Run Dialyzer (si temps acceptable)
6. Deploy Render si branch main + tests OK

## Migration Future (Phase 2)

Extraction API:
- Phoenix au-dessus reste (LiveView web)
- Ajouter endpoints GraphQL Absinthe
- Apps mobiles consomment API
- WebSocket partagé web + mobile

---

Version: 1.0
Dernière mise à jour: 30/01/2026
Validé par: Christophe Craig

