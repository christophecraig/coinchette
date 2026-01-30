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

#### 🔴 T1.2 : Configuration PostgreSQL [📝 À faire]
**Assigné** : -  
**Estimation** : 3h  
**Statut** : 📝 Next step

**Détails** :
- [ ] Docker Compose avec PostgreSQL 15
- [ ] Configuration `config/dev.exs` et `config/test.exs`
- [ ] Migrations initiales (users, games, game_states)
- [ ] Seeds de développement

**Critères d'acceptance** :
```bash
mix ecto.create
mix ecto.migrate
mix ecto.seed
# → DB prête avec données de test
```

**Dépendances** :
- T1.1 ✅

**Fichiers à créer/modifier** :
- `docker-compose.yml`
- `priv/repo/migrations/XXXXXX_create_users.exs`
- `priv/repo/migrations/XXXXXX_create_games.exs`
- `priv/repo/seeds.exs`

---

#### 🟠 T1.3 : CI/CD GitHub Actions [📝 À faire]
**Assigné** : -  
**Estimation** : 4h  
**Statut** : 📝 Planifié

**Détails** :
- [ ] Workflow `.github/workflows/ci.yml`
- [ ] Jobs : lint, test, build
- [ ] Cache des dépendances
- [ ] Rapport de coverage (Coveralls)

**Workflow** :
```yaml
on: [push, pull_request]
jobs:
  test:
    - Setup Elixir + PostgreSQL
    - mix deps.get
    - mix test --cover
    - Upload coverage
```

**Critères d'acceptance** :
- ✅ Pipeline vert sur main
- ✅ Temps de build < 5min
- ✅ Coverage affiché sur PR

**Dépendances** :
- T1.2 (DB requise pour tests)

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
Complétées : 1/5 (20%)
En cours    : 0/5 (0%)
À faire     : 4/5 (80%)
Bloquées    : 0/5 (0%)
```

**Vélocité estimée** : 17h  
**Temps écoulé** : 2h  
**Temps restant** : 15h

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
- **Installation** : Elixir 1.19.0 + Erlang 27.2 via asdf
- **Stack confirmée** : Phoenix 1.8.3, LiveView prêt
- **Fichiers ajoutés** : .tool-versions pour asdf, README personnalisé
- **Next step** : T1.2 - Configuration PostgreSQL

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
