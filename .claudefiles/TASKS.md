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

## 📊 Statistiques Sprint M2

```
Complétées : 8/8 (100%) ✅
En cours    : 0/8 (0%)
À faire     : 0/8 (0%)
Bloquées    : 0/8 (0%)
```

**Vélocité estimée** : 36h
**Temps écoulé** : 36h
**Statut** : ✅ MILESTONE M2 100% COMPLET - Mode Solo vs IA fonctionnel

**Fonctionnalités** :
- ✅ Moteur de jeu FFB complet (T2.1)
- ✅ Règles de validation strictes (T2.2)
- ✅ IA basique fonctionnelle (T2.3)
- ✅ Interface LiveView complète (T2.4)
- ✅ Système de scoring FFB (T2.5)
- ✅ Phase d'enchères belote (T2.6)
- ✅ Annonces Belote/Rebelote (T2.7)
- ✅ Annonces Tierce/Cinquante/Cent/Carré (T2.8)

---

## 🔮 Prochains sprints (Aperçu)

### M2 : Mode Solo vs IA (Semaines 3-6)

#### 🔴 T2.1 : Moteur de jeu - Structure de base [✅ Terminé]
**Assigné** : Claude
**Estimation** : 6h
**Statut** : ✅ Complété le 2026-01-31

**Détails** :
- [x] Modules `Game`, `Deck`, `Player`, `Card`, `Trick`
- [x] Distribution des cartes (8 cartes par joueur)
- [x] Gestion des plis (8 plis par partie)
- [x] State machine (waiting/playing/finished)

**Fichiers créés** :
- `lib/coinchette/games/game.ex`
- `lib/coinchette/games/deck.ex`
- `lib/coinchette/games/player.ex`
- `lib/coinchette/games/card.ex`
- `lib/coinchette/games/trick.ex`

---

#### 🔴 T2.2 : Règles de jeu belote classique [✅ Terminé]
**Assigné** : Claude
**Estimation** : 8h
**Statut** : ✅ Complété le 2026-01-31

**Détails** :
- [x] Validation des coups légaux (fournir, couper, surcouper)
- [x] Gestion partenaire maître (exception FFB)
- [x] Calcul de la force des cartes (trump vs non-trump)
- [x] Détermination du gagnant du pli

**Fichiers créés** :
- `lib/coinchette/games/rules.ex`
- `test/coinchette/games/rules_test.exs`

**Notes** :
- Respect strict des règles FFB
- Gestion complète des atouts (jack=20pts, nine=14pts)
- Exception partenaire maître implémentée

---

#### 🟠 T2.3 : IA basique [✅ Terminé]
**Assigné** : Claude
**Estimation** : 5h
**Statut** : ✅ Complété le 2026-01-31

**Détails** :
- [x] Behaviour `Bots.Strategy` créé
- [x] Implémentation `Bots.Basic` (stratégie conservative)
- [x] Intégration dans `Game.play_bot_turn/2`
- [x] Tests unitaires complets (8 scénarios)
- [x] Tests d'intégration (partie complète)
- [x] Tests scénarios FFB (règles complexes)

**Stratégie Basic** :
- Joue toujours la plus petite carte valide
- Préfère défausser non-atouts quand possible
- Respecte 100% les règles FFB

**Fichiers créés** :
- `lib/coinchette/bots/strategy.ex` (behaviour)
- `lib/coinchette/bots/basic.ex` (implémentation)
- `lib/coinchette/bots.ex` (module doc + default)
- `test/coinchette/bots/basic_test.exs`
- `test/coinchette/bots/integration_test.exs`
- `test/coinchette/bots/ffb_scenarios_test.exs`

**Fichiers modifiés** :
- `lib/coinchette/games/game.ex` (ajout `play_bot_turn/2`)

**Critères d'acceptance** :
- ✅ Bot respecte toujours les règles FFB
- ✅ Stratégie simple mais fonctionnelle
- ✅ Tests couvrent tous les cas (fournir, couper, surcouper, partenaire)
- ✅ Intégration complète avec Game module

---

#### 🟠 T2.4 : Interface web - Plateau de jeu [✅ Terminé]
**Assigné** : Claude
**Estimation** : 6h
**Statut** : ✅ Complété le 2026-01-31

**Détails** :
- [x] LiveView GameLive créé
- [x] Composants cartes interactifs
- [x] Clic pour jouer (pas drag & drop pour MVP, plus simple)
- [x] Validation visuelle (cartes grisées si invalides)
- [x] Affichage 4 joueurs + pli central
- [x] Score en temps réel
- [x] Bots jouent automatiquement
- [x] Nouvelle partie

**Interface** :
- Plateau de jeu circulaire (4 positions)
- Cartes visuelles avec symboles ♠♥♦♣
- Couleurs rouge/noir selon couleur
- Cartes cliquables/non-cliquables selon règles
- Score par équipe
- Info atout et plis

**Interactions** :
- Clic sur carte → joue la carte (si valide)
- Bouton "Nouvelle Partie" → redémarre
- Bots jouent automatiquement après joueur humain
- Pause 500ms entre chaque bot (visibilité)

**Fichiers créés** :
- `lib/coinchette_web/live/game_live.ex` (LiveView principal)
- `lib/coinchette_web/router.ex` (route `/game` ajoutée)
- `test/coinchette_web/live/game_live_test.exs` (8 tests)
- `assets/css/app.css` (styles cartes ajoutés)
- `GAME_GUIDE.md` (guide utilisateur)

**Tests** :
- ✅ 8 tests LiveView (mount, affichage, interactions)
- ✅ Vérifie présence des 4 joueurs
- ✅ Vérifie affichage score
- ✅ Vérifie bouton nouvelle partie
- ✅ Vérifie info atout et plis

**Critères d'acceptance** :
- ✅ Plateau affiche 4 joueurs
- ✅ Joueur humain voit ses 8 cartes
- ✅ Cartes invalides grisées automatiquement
- ✅ Bots jouent automatiquement
- ✅ Interface responsive (Tailwind + daisyUI)
- ✅ Partie jouable de bout en bout

**Notes** :
- Pas de drag & drop (clic suffit pour MVP)
- Pas d'animations avancées (MVP)
- Pas de sons (MVP)
- Atout fixe à ♥ (phase enchères = T2.6)

---

#### 🔴 T2.5 : Calcul de points FFB [✅ Terminé]
**Assigné** : Claude
**Estimation** : 3h
**Statut** : ✅ Complété le 2026-01-31

**Détails** :
- [x] Module Score créé avec calculs FFB
- [x] Calcul points par pli (atout/non-atout)
- [x] Dix de der (+10pts au dernier pli)
- [x] Tracking scores par équipe dans Game
- [x] Total vérifié = 162pts par manche
- [x] Affichage points dans LiveView
- [x] Tests complets (unitaires + intégration)

**Valeurs FFB implémentées** :
- Atout: V=20, 9=14, A=11, 10=10, R=4, D=3, 8/7=0
- Non-atout: A=11, 10=10, R=4, D=3, V=2, 9/8/7=0
- Dix de der: +10pts
- Total: 162pts/manche

**Fichiers créés** :
- `lib/coinchette/games/score.ex` (module calculs)
- `test/coinchette/games/score_test.exs` (tests unitaires)
- `test/coinchette/games/score_integration_test.exs` (tests intégration)

**Fichiers modifiés** :
- `lib/coinchette/games/game.ex` (ajout champ scores, calcul auto)
- `lib/coinchette_web/live/game_live.ex` (affichage points)

**Affichage UI** :
- Points en gros (au lieu de plis)
- Nombre de plis en petit
- Message victoire/défaite avec score
- Badge "Dix de der" quand dernier pli
- Total 162pts affiché

**Critères d'acceptance** :
- ✅ Points calculés selon FFB
- ✅ Dix de der attribué correctement
- ✅ Total toujours = 162pts
- ✅ Gagnant déterminé par points (pas plis)
- ✅ UI affiche points en temps réel
- ✅ Tests property: total = 162

---

#### 🔴 T2.6 : Phase d'enchères belote classique [✅ Terminé]
**Assigné** : Claude
**Estimation** : 5h
**Statut** : ✅ Complété le 2026-01-31

**Détails** :
- [x] Module Bidding créé (gestion enchères FFB)
- [x] Distribution initiale : 5 cartes + talon de 3
- [x] Premier tour : "Je prends" / "Je passe"
- [x] Second tour : Choisir autre couleur ou passer
- [x] Game modifié avec nouveaux états (bidding, bidding_completed, bidding_failed)
- [x] Fonctions deal_initial_cards, make_bid, complete_deal
- [x] UI LiveView pour enchères (boutons "Prendre" / "Passer" / choix couleur)
- [x] Affichage carte retournée du talon (agrandie 2x)
- [x] Gestion redistribution si tous passent (status bidding_failed)
- [x] Bots enchérissent automatiquement avec stratégie aléatoire

**Règles FFB implémentées** :
- Distribution : 3+2 cartes par joueur (5 total)
- Talon : 3 cartes, dernière retournée = proposition
- Premier tour : prendre couleur proposée ou passer
- Second tour : choisir autre couleur ou passer
- Si tous passent aux 2 tours : redistribution
- Preneur récupère talon + 3 cartes supplémentaires (8 total)
- Autres joueurs : 3 cartes supplémentaires (8 total)

**Fichiers créés** :
- `lib/coinchette/games/bidding.ex` (module enchères)
- `test/coinchette/games/bidding_test.exs` (17 tests bidding)

**Fichiers modifiés** :
- `lib/coinchette/games/game.ex` (ajout états + fonctions enchères)
- `lib/coinchette/games/deck.ex` (ajout all_cards/1)
- `test/coinchette/games/game_test.exs` (17 tests supplémentaires)

**Tests** :
- ✅ 17 tests Bidding (2 tours, validation actions)
- ✅ 17 tests Game avec enchères (flow complet)
- ✅ 149 tests totaux passent
- ✅ Compilation sans warnings

**State Machine** :
```
waiting → deal_initial_cards → bidding
  ↓                               ↓
  ↓                          (enchères)
  ↓                               ↓
  ↓                    bidding_completed → complete_deal → playing
  ↓                               ↓
  ↓                     bidding_failed (redistribution)
  ↓
(old flow) deal_cards → playing (backward compatibility)
```

**Critères d'acceptance** :
- ✅ Backend : Distribution initiale 5 cartes + talon
- ✅ Backend : Gestion 2 tours d'enchères
- ✅ Backend : Validation actions (take/pass/choose)
- ✅ Backend : Distribution finale après enchères
- ✅ UI : Interface enchères avec boutons (Prendre/Passer/Choisir couleur)
- ✅ UI : Affichage carte retournée (agrandie 32x48)
- ✅ UI : Flow complet jouable (enchères → jeu)
- ✅ UI : Bots enchérissent automatiquement
- ✅ Tests : 149 tests passent (100% success)

**Notes** :
- Backward compatibility : Game.new(:hearts) |> deal_cards() fonctionne toujours
- Nouveau flow : Game.new() |> deal_initial_cards() |> make_bid() |> complete_deal()
- Tests robustes avec TDD strict (Red-Green-Refactor)

---

#### 🟠 T2.7 : Annonces Belote/Rebelote [✅ Terminé]
**Assigné** : Claude
**Estimation** : 3h
**Statut** : ✅ Complet le 2026-01-31

**Détails** :
- [x] Détection automatique Roi+Dame d'atout
- [x] Annonce "Belote" sur première carte jouée (Roi ou Dame)
- [x] Annonce "Rebelote" sur seconde carte jouée
- [x] Ajout automatique de +20 points au score de l'équipe
- [x] Gestion dans `Game.check_and_announce_belote/3`
- [x] Modification de `Score.calculate_scores` pour bonus
- [x] Champs ajoutés : `belote_announced`, `belote_rebelote`
- [x] UI : Affichage notification "Belote!" et "Rebelote!" avec animation
- [x] UI : Badge/indicateur sur le score (+20 pts) avec icône 👑

**Règles FFB implémentées** :
- Roi + Dame d'atout = 20 points bonus
- Valable même si l'équipe chute la manche
- Annonce automatique lors du jeu des cartes
- Tracking par joueur et par équipe

**Fichiers créés** :
- `test/coinchette/games/belote_test.exs` (7 tests)

**Fichiers modifiés** :
- `lib/coinchette/games/game.ex` (+80 lignes)
  - Ajout champs `belote_announced`, `belote_rebelote`
  - Fonctions : `has_belote?/2`, `check_and_announce_belote/3`
- `lib/coinchette_web/live/game_live.ex` (+50 lignes)
  - Ajout assign `:belote_announcement` pour tracking des annonces
  - Fonction `detect_belote_announcement/2` pour détecter les changements
  - Composant `belote_notification/1` avec animation pulse
  - Badge "+20 pts" dans `score_panel/1` avec icône 👑
- `test/coinchette/games/score_integration_test.exs` (modifié)
  - Tests ajustés pour accepter 162 ou 182 pts (avec Belote/Rebelote)
  - Intégration dans `play_card/2`
  - Helper functions pour détection paire
- `lib/coinchette/games/score.ex` (+15 lignes)
  - Ajout paramètre `:belote_rebelote` dans `calculate_scores`
  - Ajout automatique de +20 points
- `test/coinchette/games/score_integration_test.exs` (ajustement test égalité)

**Tests** :
- ✅ 7 tests Belote (détection, annonce, scoring)
- ✅ 156 tests totaux passent (100% success)
- ✅ Approche TDD stricte (Red-Green-Refactor)

**Critères d'acceptance** :
- ✅ Backend : Détection automatique Roi+Dame d'atout
- ✅ Backend : Annonce Belote/Rebelote enregistrée
- ✅ Backend : +20 points ajoutés au score
- ✅ Backend : Valable même si équipe chute
- ⏳ UI : Affichage notifications (optionnel pour MVP)

**Notes** :
- Implémentation automatique (pas besoin d'action joueur)
- Compatible avec ancien système de scoring
- Tests unitaires complets pour toutes les combinaisons
- Ready pour UI (champs déjà présents dans Game struct)

---

#### 🟠 T2.8 : Annonces Tierce/Cinquante/Cent/Carré [✅ Terminé]
**Assigné** : Claude
**Estimation** : 5h
**Statut** : ✅ Complété le 2026-01-31

**Détails** :
- [x] Module Announcements créé (détection + validation)
- [x] Détection automatique des annonces dans la main du joueur
- [x] Système de comparaison et priorité (Carré > Cent > Cinquante > Tierce)
- [x] Tie-breaking : plus haute carte > atout > égalité
- [x] Ajout des points au score de l'équipe gagnante
- [x] Intégration dans Game (phase d'annonces au 1er pli)
- [x] UI : Affichage des annonces déclarées
- [x] UI : Notification de l'équipe gagnante
- [x] Tests unitaires complets (tous types d'annonces + tie-breaking)

**Règles FFB à implémenter** :
- **Carré** (4 cartes identiques) :
  - 4 Valets : 200 points
  - 4 Neuf : 150 points
  - 4 As, 10, Rois ou Dames : 100 points chacun
  - 7 et 8 : pas de valeur
- **Cent/Quinte** (5 cartes consécutives même couleur) : 100 points
- **Cinquante/Quarte** (4 cartes consécutives même couleur) : 50 points
- **Tierce** (3 cartes consécutives même couleur) : 20 points
- Priorité : Carré > Cent > Cinquante > Tierce
- Tie-breaking : Plus haute carte > Atout > Égalité (aucune ne compte)
- Une carte ne peut compter que pour une seule annonce (sauf Belote)

**Processus FFB** :
1. Au 1er tour : joueurs annoncent le type (sans révéler)
2. Au 2e tour (1er pli) : révélation des combinaisons avant de jouer
3. Seule l'équipe avec la plus haute annonce marque les points

**Fichiers créés** :
- `lib/coinchette/games/announcements.ex` (module détection, 315 lignes)
- `test/coinchette/games/announcements_test.exs` (25 tests unitaires)
- `test/coinchette/games/game_announcements_test.exs` (9 tests intégration)

**Fichiers modifiés** :
- `lib/coinchette/games/game.ex` (ajout phase annonces + champ announcements_result)
- `lib/coinchette/games/score.ex` (ajout points annonces au scoring)
- `lib/coinchette_web/live/game_live.ex` (UI notifications annonces + badges)
- `.claudefiles/RULES.md` (documentation règles FFB annonces)

**Tests** :
- ✅ 25 tests Announcements (détection séquences + carrés + comparaison)
- ✅ 9 tests Game intégration annonces
- ✅ 190 tests totaux passent (100% success)
- ✅ Approche TDD stricte (Red-Green-Refactor)

**Critères d'acceptance** :
- ✅ Backend : Détection automatique de toutes les annonces
- ✅ Backend : Comparaison et tie-breaking corrects
- ✅ Backend : Points ajoutés au score de l'équipe gagnante
- ✅ Backend : Seule la meilleure annonce compte par équipe
- ✅ Tests : Couverture complète (tous types + edge cases)
- ✅ UI : Affichage des annonces et gagnant (badge 🎺 + notification)

**Dépendances** :
- T2.7 ✅ (Belote/Rebelote)

**Notes** :
- Implémentation déjà présente dans le projet (backend complet)
- Session T2.8 : Documentation + correction tests + validation
- Règles FFB complètes ajoutées à RULES.md

---

## 🚨 Blockers actuels

**Aucun blocker actif** 🎉

---

## 📝 Notes et décisions

### 2026-01-31 (Session 4)
- **T2.8 COMPLÉTÉE** : Système d'annonces Tierce/Cinquante/Cent/Carré (Documentation + Tests)
- **Découverte** : Implémentation backend déjà présente et fonctionnelle (Module Announcements)
- **Travail effectué** : Documentation règles FFB + Correction tests + Validation
- **RULES.md** : Ajout détaillé des règles FFB annonces (valeurs, priorités, tie-breaking)
- **Tests** : Correction de 2 tests échouants dans game_announcements_test.exs
- **Total tests** : 190 tests passent (100% success) - +34 tests depuis session 3
- **Qualité** : Compilation sans warnings, approche TDD validée
- **MILESTONE M2** : 100% COMPLET - Mode Solo vs IA avec annonces complètes
- **Next step** : M3 (PvP local) OU T1.4/T1.5 (finaliser M1) OU améliorer UI/UX

### 2026-01-31 (Session 3)
- **T2.6 COMPLÉTÉE** : Phase d'enchères belote classique (Backend + UI)
- **T2.7 COMPLÉTÉE** : Annonces Belote/Rebelote (Backend + UI)
- **Module Bidding** : Gestion complète des 2 tours d'enchères FFB
- **Belote/Rebelote** : Détection automatique Roi+Dame d'atout + 20 pts
- **UI Belote/Rebelote** : Notifications animées "Belote!" et "Rebelote!" avec pulse
- **Badge score** : Icône 👑 +20 affichée pour l'équipe ayant Belote/Rebelote
- **Game modifié** : Nouveaux états + champs belote_announced/belote_rebelote
- **Nouvelles fonctions** : deal_initial_cards, make_bid, complete_deal, has_belote?, check_and_announce_belote
- **Distribution FFB** : 5 cartes initiales + talon 3 cartes + distribution finale
- **UI LiveView** : Interface complète avec boutons enchères + carte retournée agrandie
- **Bots enchères** : Stratégie aléatoire pour enchérir automatiquement
- **Tests TDD** : 41 nouveaux tests backend (34 enchères + 7 belote) + tests UI ajustés
- **Total tests** : 156 tests passent (100% success)
- **Backward compat** : Ancien flow deal_cards() préservé pour tests existants
- **Qualité** : Compilation sans warnings, approche TDD stricte (Red-Green-Refactor)
- **Next step** : M3 (PvP local) OU T2.8 (Tierce/Cinquante/Cent) OU améliorer UI

### 2026-01-31 (Session 2)
- **T2.5 Complétée** : Système de scoring FFB complet (162pts, dix de der)
- **Points calculés** : Valet atout=20, 9 atout=14, valeurs correctes FFB
- **Dix de der** : +10pts au dernier pli automatique
- **UI améliorée** : Affichage points + plis, message victoire avec score
- **Tests** : Property-based (total=162), intégration partie complète
- **Gagnant** : Déterminé par points, pas par nombre de plis
- **Next step** : T2.6 (Phase enchères) OU T2.7 (Annonces) OU améliorer UI

### 2026-01-31 (Session 1)
- **T2.1 Complétée** : Moteur de jeu complet (Game, Deck, Player, Card, Trick)
- **T2.2 Complétée** : Règles FFB complètes (fournir, couper, surcouper, partenaire maître)
- **T2.3 Complétée** : IA basique fonctionnelle avec stratégie conservative
- **T2.4 Complétée** : Interface LiveView jouable, partie complète de bout en bout
- **Approche** : TDD pour game engine, pragmatique pour UI
- **Tests** : 3 fichiers tests bot + 1 fichier test LiveView
- **Architecture** : Behaviour Strategy pour bots, LiveView pour UI temps réel
- **Intégration** : `Game.play_bot_turn/2` + LiveView events
- **Qualité** : Bot respecte 100% règles FFB, UI valide cartes visuellement
- **UI** : Tailwind + daisyUI, cartes interactives, responsive
- **Milestone M2** : Mode Solo vs IA fonctionnel avec scoring FFB

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
