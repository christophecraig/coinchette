# 🎮 Guide de Jeu Coinchette

## Démarrer une partie

### 1. Lancer le serveur

```bash
mix phx.server
```

### 2. Ouvrir le navigateur

Naviguer vers : `http://localhost:4000/game`

## Comment jouer

### Interface

L'interface affiche :
- **Vous (Sud)** : Votre main en bas de l'écran
- **Nord, Est, Ouest** : Les 3 bots (dos de cartes visibles)
- **Centre** : Le pli en cours
- **Droite** : Score et informations

### Jouer une carte

1. **Attendez votre tour** : Le message "Votre tour de jouer" s'affiche
2. **Cartes jouables** : Les cartes valides sont en surbrillance bleue
3. **Cartes invalides** : Grisées et non-cliquables (règles FFB)
4. **Cliquez** sur une carte jouable pour la jouer

### Déroulement

1. Vous jouez une carte
2. Les 3 bots jouent automatiquement (pause 500ms entre chaque)
3. Le gagnant du pli est déterminé
4. Le prochain pli commence
5. Après 8 plis, la partie se termine

### Règles appliquées (FFB)

- ✅ **Fournir** : Vous devez jouer la couleur demandée si vous l'avez
- ✅ **Couper** : Si pas la couleur, vous devez couper avec atout
- ✅ **Surcouper** : Si adversaire a coupé, vous devez monter
- ✅ **Partenaire maître** : Pas d'obligation si votre partenaire gagne

Les cartes invalides sont automatiquement grisées !

## Nouvelle partie

Cliquez sur le bouton **"Nouvelle Partie"** en haut pour recommencer.

## Atout

L'atout actuel est affiché dans la section "Info" à droite.
Pour l'instant, l'atout est fixe (♥ Cœur) au démarrage.

## Score

Le score montre le nombre de plis remportés par chaque équipe :
- **Équipe 0** : Vous (Sud) + Nord
- **Équipe 1** : Est + Ouest

## Stratégie des bots

Les bots utilisent la stratégie **Basic** :
- Jouent toujours la plus petite carte valide
- Préfèrent défausser des non-atouts
- Respectent 100% les règles FFB

## Raccourcis

Aucun raccourci clavier pour l'instant (prévu V2).

## Problèmes connus

- [ ] Pas d'animation de déplacement des cartes
- [ ] Pas de son
- [ ] Pas de choix d'atout (fixe à ♥)
- [ ] Bots jouent instantanément (pause artificielle de 500ms)

## Prochaines fonctionnalités

- [ ] Phase d'enchères (choix atout)
- [ ] Annonces (belote, tierce, etc.)
- [ ] Calcul points détaillé
- [ ] Animations fluides
- [ ] Sons de cartes
- [ ] Mode multijoueur en ligne

---

**Version** : MVP 0.1
**Date** : 2026-01-31
