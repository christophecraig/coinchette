# 🎨 Guide des Animations UX

Ce document décrit toutes les animations CSS disponibles dans Coinchette et comment les utiliser.

## Animations de Cartes

### `.card-enter`
Animation d'apparition basique (slide in from top).
```heex
<div class="card-enter">...</div>
```

### `.card-deal`
Animation de distribution des cartes (bounce effect).
```heex
<div class="card-deal">...</div>
```
**Usage** : Ajouter cette classe quand les cartes sont distribuées au début d'une partie.

### `.card-play`
Animation quand une carte est jouée vers le centre.
```heex
<div class="card-play">...</div>
```
**Usage** : Ajouter cette classe aux cartes dans le trick zone.

### `.card-win`
Animation de victoire du pli (pulse avec glow).
```heex
<div class="card-win">...</div>
```
**Usage** : Ajouter temporairement aux cartes gagnantes avant de les retirer.

## Styles de Cartes

### `.playing-card`
Style de base pour toutes les cartes à jouer.
- **Hover** : Scale 110%, translate up, glow effect
- **Active** : Press down effect
- **Disabled** : Grayscale + opacity

```heex
<div class="playing-card" class={if !playable, do: "disabled"}>
  <!-- Contenu de la carte -->
</div>
```

### `.trick-card`
Classe pour cartes dans le trick zone (inclut animation play).
```heex
<div class="playing-card trick-card">...</div>
```

## Zone de Jeu

### `.trick-zone`
Zone centrale où les cartes sont jouées.
```heex
<div class="trick-zone" class={if has_cards?, do: "has-cards"}>
  <!-- Cartes jouées -->
</div>
```

**Variants** :
- `.has-cards` : Ajoute un glow effect quand des cartes sont présentes

## Boutons

### `.btn` (amélioration)
Tous les boutons daisyUI ont maintenant :
- **Hover** : Translate up + shadow
- **Active** : Press down effect

Automatique, rien à ajouter.

## Notifications

### `.alert`
Les alertes daisyUI ont une animation slide-in-from-top.

Automatique pour tous les composants `.alert`.

## Scores

### `.score-update`
Flash bleu quand le score change.
```heex
<div class="score-update">Points: {@score}</div>
```

**Usage** : Ajouter temporairement (500ms) quand le score change.

## Utilitaires

### `.pulse-slow`
Pulse lent pour indiquer un état d'attente.
```heex
<div class="pulse-slow">En attente...</div>
```

### `.spinner`
Rotation pour indicateurs de chargement.
```heex
<div class="spinner">⏳</div>
```

### `.page-transition`
Fade in pour transitions de page.
```heex
<div class="page-transition">
  <!-- Contenu de la page -->
</div>
```

## Exemples d'Implémentation

### Distribution de cartes au début de partie

```elixir
def render(assigns) do
  ~H"""
  <div :for={{card, index} <- Enum.with_index(@hand)}
       class="playing-card card-deal"
       style={"animation-delay: #{index * 0.1}s"}>
    <.card_component card={card} />
  </div>
  """
end
```

### Carte jouée vers le centre

```elixir
defp trick_card(assigns) do
  ~H"""
  <div class="playing-card trick-card">
    <.card_component card={@card} />
  </div>
  """
end
```

### Score qui change avec animation

```elixir
def handle_info({:score_updated, new_score}, socket) do
  # Ajouter classe temporairement
  socket = assign(socket, score_animating: true)
  Process.send_after(self(), :remove_score_animation, 500)

  {:noreply, assign(socket, score: new_score)}
end

def handle_info(:remove_score_animation, socket) do
  {:noreply, assign(socket, score_animating: false)}
end

# Dans le template
~H"""
<div class={if @score_animating, do: "score-update"}>
  Score: {@score}
</div>
"""
```

### Cartes gagnantes avec effet

```elixir
def handle_event("show_trick_winner", _params, socket) do
  socket = assign(socket, show_winner: true)

  # Après 600ms, retirer les cartes
  Process.send_after(self(), :clear_trick, 600)

  {:noreply, socket}
end

# Dans le template
~H"""
<div :for={card <- @trick_cards}
     class={["playing-card", @show_winner && "card-win"]}>
  <.card_component card={card} />
</div>
"""
```

## Performance

**Notes importantes** :
- Les animations utilisent `transform` et `opacity` (GPU accelerated)
- Éviter d'animer `width`, `height`, `top`, `left` (cause reflow)
- Les animations sont désactivées si l'utilisateur a `prefers-reduced-motion`
- Durée recommandée : 200-500ms pour la plupart des animations

## Accessibilité

Pour respecter les préférences utilisateur :

```css
@media (prefers-reduced-motion: reduce) {
  .playing-card,
  .card-enter,
  .card-deal,
  .card-play,
  .card-win {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

À ajouter dans app.css si nécessaire.

---

**Créé** : 2026-01-31
**Dernière mise à jour** : 2026-01-31
**Version** : 1.0
