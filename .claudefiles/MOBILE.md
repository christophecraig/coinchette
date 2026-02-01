# 📱 Guide Mobile & Responsive

Ce document décrit toutes les optimisations mobiles et responsive de Coinchette.

## Breakpoints Tailwind

```
sm:  640px  (tablettes portrait)
md:  768px  (tablettes landscape)
lg:  1024px (petits laptops)
xl:  1280px (desktops)
2xl: 1536px (grands écrans)
```

## Optimisations par Taille d'Écran

### Mobile (< 640px)

**Cartes à jouer** :
- Taille minimale : 60x84px
- Animation réduite à 200ms (performance)
- Espacement augmenté pour touch

**Boutons** :
- Hauteur minimale : 48px (12 rem)
- Padding horizontal : 24px (6 rem)
- Largeur complète par défaut (.mobile-full)

**Header** :
- Titre réduit à text-2xl
- Message en text-sm
- Padding réduit (p-4)

**Trick Zone** :
- Taille réduite : 150x150px

**Chat** :
- Hauteur max : 240px (60 rem)

**Utilitaires** :
- `.mobile-hide` : cache éléments non essentiels
- `.mobile-compact` : réduit padding (p-4)

### Tablette (641px - 1024px)

**Cartes** :
- Taille : 70x98px

**Trick Zone** :
- Taille : 180x180px

### Landscape Mobile (hauteur < 500px)

**Optimisations verticales** :
- Cartes réduites : 50x70px
- Trick zone : 120x120px
- Titre en text-xl
- Score détails cachés (.score-details)
- Padding vertical réduit

## Touch Optimization

### Cibles Touch (pointer: coarse)

**Tailles minimales** :
- 44x44px pour tous boutons et cartes (Apple HIG)
- Padding augmenté sur cartes (+0.25rem)

**Hover désactivé** :
- Effet hover réduit (scale 105% au lieu de 110%)
- Translate réduit (-0.25rem au lieu de -0.5rem)

### Gestures Supportés

- **Tap** : Jouer une carte
- **Long press** : Voir détails (futur)
- **Swipe** : Navigation (futur)

## Performance Mobile

### Animations Réduites

Sur mobile, toutes les animations sont accélérées :
- `animation-duration: 0.2s` (au lieu de 0.3-0.6s)
- GPU acceleration via `transform` et `opacity`

### Préférences Système

**Reduced Motion** :
```css
@media (prefers-reduced-motion: reduce) {
  /* Animations quasi-instantanées */
  animation-duration: 0.01ms !important;
}
```

**Dark Mode** :
```css
@media (prefers-color-scheme: dark) {
  /* Table de jeu plus sombre */
}
```

## Classes Utilitaires Mobile

### Dans les Templates

```heex
<!-- Padding responsive -->
<div class="p-4 sm:p-6 lg:p-8">

<!-- Texte responsive -->
<h1 class="text-2xl sm:text-3xl lg:text-4xl">

<!-- Bouton full width sur mobile -->
<button class="w-full sm:w-auto btn">

<!-- Cacher sur mobile -->
<div class="hidden sm:block">

<!-- Grid responsive -->
<div class="grid grid-cols-1 lg:grid-cols-4">
```

### Exemples d'Implémentation

#### Header Responsive

```heex
<div class="p-4 sm:p-6 lg:p-8">
  <h1 class="text-2xl sm:text-3xl lg:text-4xl font-bold">
    Titre
  </h1>
  <p class="text-sm sm:text-base lg:text-lg">
    Description
  </p>
</div>
```

#### Boutons Responsive

```heex
<!-- Full width sur mobile, auto sur desktop -->
<button class="btn btn-primary w-full sm:w-auto">
  Action
</button>

<!-- Stack vertical sur mobile, horizontal sur desktop -->
<div class="flex flex-col sm:flex-row gap-2">
  <button class="btn">Option 1</button>
  <button class="btn">Option 2</button>
</div>
```

#### Grid Responsive

```heex
<!-- 1 colonne mobile, 2 tablette, 4 desktop -->
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
  <div>Item 1</div>
  <div>Item 2</div>
  <div>Item 3</div>
  <div>Item 4</div>
</div>
```

#### Cartes de Jeu Responsive

```heex
<div class="grid grid-cols-4 sm:grid-cols-6 lg:grid-cols-8 gap-2">
  <div :for={card <- @hand} class="playing-card">
    <.card_component card={card} />
  </div>
</div>
```

## Tests Mobile Recommandés

### Appareils à Tester

**Priorité 1** (80% des utilisateurs) :
- iPhone SE (375x667)
- iPhone 12/13/14 (390x844)
- Samsung Galaxy S21 (360x800)

**Priorité 2** :
- iPad (768x1024)
- iPad Pro (1024x1366)
- Pixel 5 (393x851)

**Landscape** :
- Tous appareils en mode paysage

### Checklist UX Mobile

- [ ] Touch targets >= 44x44px
- [ ] Texte lisible (>= 16px base)
- [ ] Pas de scroll horizontal
- [ ] Boutons accessibles (pas trop haut/bas)
- [ ] Animations fluides (60fps)
- [ ] Pas de hover requis (tout fonctionne au tap)
- [ ] Temps de chargement < 3s
- [ ] Fonctionne offline (cache)

## Viewport Configuration

Dans `root.html.heex` :

```html
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
```

**Note** : `user-scalable=no` peut poser des problèmes d'accessibilité. À évaluer.

## PWA Mobile (Futur)

### manifest.json

```json
{
  "name": "Coinchette",
  "short_name": "Coinchette",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#155724",
  "theme_color": "#1e7e34",
  "icons": [
    {
      "src": "/images/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/images/icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

### Service Worker

À implémenter pour :
- Cache des assets
- Fonctionnement offline
- Notifications push

## Accessibilité Mobile

### Contraste

- Ratio minimum : 4.5:1 (AA)
- Ratio recommandé : 7:1 (AAA)

### Espacement

- Minimum entre éléments cliquables : 8px
- Padding touch zones : 12px

### Labels

- Tous boutons ont aria-label ou texte visible
- Images ont alt text

## Debugging Mobile

### Chrome DevTools

```
F12 > Toggle Device Toolbar (Ctrl+Shift+M)
```

### Remote Debugging

**Android** :
```
chrome://inspect
```

**iOS** :
```
Safari > Develop > [Device]
```

### Performance

```javascript
// Dans la console
performance.mark('start');
// ... action
performance.mark('end');
performance.measure('action', 'start', 'end');
```

---

**Créé** : 2026-01-31
**Dernière mise à jour** : 2026-01-31
**Version** : 1.0
