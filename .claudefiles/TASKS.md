# 📋 Tasks Coinchette

**Dernière mise à jour** : 2026-01-30  
**Sprint actuel** : M1 - Infrastructure & Setup (Semaines 1-2)

---

## 🎯 Légende

- ⏳ **En cours** : Tâche active
- ✅ **Terminé** : Complété et testé
- 📝 **À faire** : Planifié pour ce sprint
- 🚧 **Bloqué** : Attend une dépendance
- 🔄 **En review** : Code prêt, en relecture
- ⏸️ **En pause** : Reporté temporairement
- ❌ **Abandonné** : Ne sera pas fait

**Priorités** : 🔴 Critique | 🟠 Haute | 🟡 Moyenne | 🟢 Basse

---

## 📅 Sprint en cours : M1 - Infrastructure (Semaines 1-2)

### Objectif du sprint
Mettre en place l'infrastructure de base : projet Phoenix, DB, CI/CD, tests E2E

### Tâches

#### 🔴 T1.1 : Setup projet Phoenix [✅ Terminé]
**Assigné** : Claude
**Estimation** : 2h
**Statut** : ✅ Complété le 2026-01-30

**Détails** :
- [x] `mix phx.new coinchette --database postgres`
- [x] Configuration .gitignore (amélioré avec .env, IDE files)
- [x] README.md initial (personnalisé pour Coinchette)
- [x] Structure dossiers de base
- [x] Fichier .tool-versions pour asdf

**Tests** :
- [x] Projet compile sans erreurs
- [ ] `mix test` passe (requiert T1.2 - config DB)
- [ ] Serveur démarre sur localhost:4000 (requiert T1.2 - config DB)

**Fichiers créés/modifiés** :
- `mix.exs` (généré)
- `config/*.exs` (généré)
- `README.md` (personnalisé)
- `.gitignore` (amélioré)
- `.tool-versions` (créé)
- `lib/`, `test/`, `priv/` (structure complète)

---

#### 🔴 T1.2 : Configuration PostgreSQL [✅ Terminé]
**Assigné** : Claude
**Estimation** : 3h
**Statut** : ✅ Complété le 2026-01-30

**Détails** :
- [x] PostgreSQL 18.1 local utilisé (déjà installé)
- [x] docker-compose.yml créé (optionnel, PG local fonctionnel)
- [x] Configuration `config/dev.exs` et `config/test.exs` (par défaut Phoenix)
- [x] Migrations initiales (users, games, game_players)
- [x] Seeds de développement (structure prête)

**Critères d'acceptance** :
- ✅ `mix ecto.create` - DB créée
- ✅ `mix ecto.migrate` - Tables créées (users, games, game_players)
- ✅ `mix test` - 5 tests passent
- ✅ `mix phx.server` - Serveur démarre sur localhost:4000

**Dépendances** :
- T1.1 ✅

**Fichiers créés/modifiés** :
- `docker-compose.yml` (créé, non utilisé)
- `priv/repo/migrations/20260130224741_create_users.exs` (créé)
- `priv/repo/migrations/20260130224742_create_games.exs` (créé)
- `priv/repo/migrations/20260130224815_create_game_players.exs` (créé)
- `priv/repo/seeds.exs` (modifié)

---

#### 🟠 T1.3 : CI/CD GitHub Actions [✅ Terminé]
**Assigné** : Claude
**Estimation** : 4h
**Statut** : ✅ Complété le 2026-01-30

**Détails** :
- [x] Workflow `.github/workflows/ci.yml` créé
- [x] Job test : compile, format, migrations, tests
- [x] Job lint : Credo strict mode
- [x] Job security : mix deps.audit
- [x] Cache des dépendances (deps + _build)
- [x] PostgreSQL 18 service pour tests
- [x] Configuration .credo.exs

**Workflow** :
```yaml
on: [push, pull_request]
jobs:
  test: Elixir setup, PostgreSQL, compile, format, test
  lint: Credo --strict
  security: deps.audit
```

**Critères d'acceptance** :
- ✅ Tous les checks passent localement
- ✅ mix compile --warnings-as-errors ✅
- ✅ mix format --check-formatted ✅
- ✅ mix credo --strict (0 issues) ✅
- ✅ mix deps.audit (0 vulns) ✅
- ✅ mix test (5 tests) ✅
- ⏸️ Pipeline GitHub (en attente de push sur repo)

**Dépendances** :
- T1.2 ✅

**Fichiers créés** :
- `.github/workflows/ci.yml`
- `.credo.exs`
- `mix.exs` (ajout credo, mix_audit)

---

#### 🟠 T1.4 : Tests E2E Playwright [📝 À faire]
**Assigné** : -  
**Estimation** : 5h  
**Statut** : 📝 Planifié

**Détails** :
- [ ] Installation Playwright
- [ ] Configuration `playwright.config.js`
- [ ] Premier test : "Page d'accueil se charge"
- [ ] Intégration CI

**Test exemple** :
```javascript
test('homepage loads', async ({ page }) => {
  await page.goto('http://localhost:4000');
  await expect(page).toHaveTitle(/Coinchette/);
});
```

**Dépendances** :
- T1.1 ✅ (serveur doit démarrer)

**Fichiers à créer** :
- `e2e/homepage.spec.js`
- `playwright.config.js`

---

#### 🟡 T1.5 : Déploiement Fly.io staging [📝 À faire]
**Assigné** : -  
**Estimation** : 3h  
**Statut** : 📝 Planifié

**Détails** :
- [ ] Compte Fly.io configuré
- [ ] `fly.toml` configuration
- [ ] PostgreSQL sur Fly
- [ ] Déploiement automatique depuis `main`

**Commandes** :
```bash
fly launch
fly postgres create coinchette-db
fly deploy
```

**URL attendue** : `https://coinchette-staging.fly.dev`

**Dépendances** :
- T1.3 ✅ (CI doit être fonctionnel)

---

## 📊 Statistiques Sprint M1

```
Complétées : 3/5 (60%)
En cours    : 0/5 (0%)
À faire     : 2/5 (40%)
Bloquées    : 0/5 (0%)
```

**Vélocité estimée** : 17h
**Temps écoulé** : 9h
**Temps restant** : 8h

---

## 🔮 Prochains sprints (Aperçu)

### M2 : Mode Solo vs IA (Semaines 3-6)

#### 🔴 T2.1 : Moteur de jeu - Structure de base [📝 Planifié]
- [ ] Modules `Game`, `Deck`, `Player`
- [ ] Distribution des cartes
- [ ] Gestion des plis

#### 🔴 T2.2 : Règles de jeu belote classique [📝 Planifié]
- [ ] Validation des coups légaux
- [ ] Calcul du score
- [ ] Gestion des annonces (tierce, belote, etc.)

#### 🟠 T2.3 : IA basique [📝 Planifié]
- [ ] Algorithme de sélection de carte
- [ ] Stratégie simple (suit, coupe, défausse)

#### 🟠 T2.4 : Interface web - Plateau de jeu [📝 Planifié]
- [ ] LiveView pour le plateau
- [ ] Composants cartes
- [ ] Drag & drop

---

## 🚨 Blockers actuels

**Aucun blocker actif** 🎉

---

## 📝 Notes et décisions

### 2026-01-30
- **T1.1 Complétée** : Projet Phoenix initialisé avec succès
- **T1.2 Complétée** : PostgreSQL 18.1 configuré, migrations créées
- **T1.3 Complétée** : CI/CD GitHub Actions + Credo configurés
- **Installation** : Elixir 1.19.0 + Erlang 27.2 via asdf
- **Stack confirmée** : Phoenix 1.8.3, LiveView prêt, PostgreSQL 18.1
- **Database** : Tables users, games, game_players créées
- **CI/CD** : Workflow GitHub Actions prêt (test, lint, security)
- **Qualité** : Credo strict (0 issues), deps.audit (0 vulns)
- **Tests** : 5 tests Phoenix passent, tous les checks CI ✅
- **Fichiers ajoutés** : .tool-versions, README, migrations, CI workflow, .credo.exs
- **Next step** : T1.4 - Tests E2E Playwright OU passer à M2 (Game Engine)

### 2025-01-01
- **Décision** : PostgreSQL choisi plutôt que SQLite (scalabilité)
- **Note** : Fly.io gratuit jusqu'à 3 machines, suffisant pour staging

---

## 🎯 Définition of Done

Une tâche est considérée "Terminée" (✅) si :

1. ✅ Code écrit et fonctionnel
2. ✅ Tests unitaires/intégration passent (coverage > 80%)
3. ✅ Documentation mise à jour (commentaires, README)
4. ✅ Code review effectuée (si équipe)
5. ✅ Pas de régression sur tests existants
6. ✅ Déployé en staging (si applicable)

---

## 📞 Template de tâche

```markdown
#### 🔴 TXX.X : Titre de la tâche [📝 Statut]
**Assigné** : -  
**Estimation** : Xh  
**Statut** : 📝 / ⏳ / 🔄 / ✅ / 🚧

**Détails** :
- [ ] Sous-tâche 1
- [ ] Sous-tâche 2

**Critères d'acceptance** :
- Point de validation 1
- Point de validation 2

**Dépendances** :
- TX.X ✅

**Fichiers modifiés** :
- `chemin/fichier.ex`
```

---

**Prochaine mise à jour** : Après complétion de T1.2
