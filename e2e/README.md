# 🧪 Tests E2E Coinchette

Tests end-to-end avec Playwright pour valider les flows critiques de l'application.

## 📋 Prérequis

- Node.js 18+ (ou via asdf)
- pnpm
- Phoenix server fonctionnel

## 🚀 Installation

```bash
# Installer les dépendances
pnpm install

# Installer les navigateurs Playwright
pnpm exec playwright install chromium
```

## ▶️ Lancer les tests

```bash
# Tous les tests
pnpm test

# Tests spécifiques
pnpm test e2e/homepage.spec.js
pnpm test e2e/solo-game.spec.js
pnpm test e2e/multiplayer.spec.js

# Mode headed (voir le navigateur)
pnpm test:headed

# Mode UI interactif
pnpm test:ui

# Mode debug
pnpm test:debug

# Navigateur spécifique
pnpm test:chromium
pnpm test:firefox
pnpm test:webkit
```

## 📊 Rapport de tests

```bash
# Générer et afficher le rapport HTML
pnpm report
```

## 📁 Structure

```
e2e/
├── homepage.spec.js      # Tests homepage (✅ 3/3)
├── auth.spec.js          # Tests authentification
├── solo-game.spec.js     # Tests jeu solo (⚠️ 3/6)
├── multiplayer.spec.js   # Tests multijoueur (❌ 0/6)
├── helpers.js            # Fonctions utilitaires
└── README.md             # Cette documentation
```

## ✅ Tests actuels

### Homepage (3/3) ✅
- ✅ Page se charge correctement
- ✅ Navigation présente
- ✅ Responsive mobile

### Solo Game (3/6) ⚠️
- ✅ Affiche phase d'enchères
- ✅ Peut jouer une carte
- ✅ Affiche atout
- ❌ Démarre et joue jeu solo
- ❌ Affiche score
- ❌ Complète partie entière

### Multiplayer (0/6) ❌
- ❌ Accède au lobby (auth requis)
- ❌ Crée partie
- ❌ Ajoute bots
- ❌ Démarre partie
- ❌ Affiche chat
- ❌ Messages système

### Auth (non testé)
- Tests d'authentification à compléter

## 🔧 Améliorer les tests

### Problèmes connus

1. **Tests multijoueur échouent** : Authentification requise
   - Solution : Utiliser `loginAsTestUser()` helper
   - Créer fixture d'authentification

2. **Sélecteurs fragiles** : Dépendent de la structure HTML
   - Solution : Ajouter `data-testid` aux éléments clés
   - Exemple : `<div data-testid="player-hand">`

3. **Timeouts** : Tests longs (bots jouent)
   - Solution : Augmenter timeout ou optimiser
   - Utiliser `test.slow()` pour tests longs

### Bonnes pratiques

1. **Ajouter data-testid** dans les composants LiveView :
```elixir
<div data-testid="player-hand" class="cards">
  <%= for card <- @player.hand do %>
    <div data-testid={"card-#{card.suit}-#{card.rank}"}>
      ...
    </div>
  <% end %>
</div>
```

2. **Utiliser les helpers** :
```javascript
const { loginAsTestUser, createGameWithBots } = require('./helpers');

test('multiplayer flow', async ({ page }) => {
  await loginAsTestUser(page);
  await createGameWithBots(page, 3);
  // ...
});
```

3. **Tests robustes** :
```javascript
// ❌ Fragile
await page.click('.button-primary');

// ✅ Robuste
await page.click('[data-testid="start-game-button"]');
```

## 🎯 TODO

- [ ] Fixer tests multijoueur (auth)
- [ ] Fixer tests solo game (sélecteurs)
- [ ] Ajouter `data-testid` dans LiveView
- [ ] Tests authentification complets
- [ ] Tests chat in-game
- [ ] Tests annonces (Belote, Tierce, etc.)
- [ ] Tests responsive (mobile)
- [ ] Intégration CI/CD

## 📚 Ressources

- [Playwright Docs](https://playwright.dev)
- [Best Practices](https://playwright.dev/docs/best-practices)
- [Phoenix Testing](https://hexdocs.pm/phoenix/testing.html)

## 🐛 Debug

```bash
# Lancer tests avec traces
pnpm test --trace on

# Voir screenshot d'un échec
open test-results/*/test-failed-1.png

# Voir vidéo d'un échec
open test-results/*/video.webm

# Inspector avec Playwright Inspector
pnpm test:debug e2e/solo-game.spec.js
```

---

**Statut global** : 6/15 tests passent (40%)
**Prochaine étape** : Ajouter data-testid + fixer auth multijoueur
