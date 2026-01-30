# Coinchette - Document Projet

Pitch: La belote ou la coinche, avec ou sans amis!

## Vision

Application web de belote et coinche permettant de jouer seul contre des bots ou entre amis en ligne.

### Objectifs principaux
- Offrir une expérience de jeu fidèle aux règles FFB
- Interface simple et accessible pour tous niveaux
- Progression via 3 niveaux de difficulté de bots
- Dimension sociale via système d'amis et chat

### Public cible
- Joueurs de belote cherchant à pratiquer
- Groupes d'amis voulant jouer à distance
- Débutants souhaitant apprendre les règles

## Scope MVP (Phase 1)

### Features incluses
- Authentification utilisateur obligatoire
- Belote classique ET Coinche
- Mode solo vs 3 bots (facile/moyen/difficile)
- Mode multijoueur privé (inviter des amis)
- Historique des parties jouées
- Chat in-game
- Chat avec amis hors partie
- Classement des joueurs

### Features exclues du MVP
- Parties publiques avec joueurs inconnus
- Tournois
- Spectateurs
- Replays de parties
- Statistiques avancées
- Système de ranking ELO
- Applications mobiles natives (prévu Phase 2)

## Contraintes

### Techniques
- Hébergement: Render.com
- Base de données: PostgreSQL
- Pas de budget cloud premium
- Niveau Elixir équipe: débutant

### Design
- Approche fonctionnelle basique pour MVP
- Pas de maquettes existantes
- Focus sur l'UX de jeu plutôt que visuel

### Métier
- Respect strict des règles FFB
- Pas d'inventions de règles maison
- Validation par joueurs expérimentés avant release

## Principes de développement

### Get Shit Done
- Privilégier solutions simples et éprouvées
- Éviter sur-ingénierie
- Itérations courtes avec feedback
- Tester tôt et souvent

### Qualité
- TDD strict sur logique métier
- Code review systématique
- Documentation du "pourquoi" pas du "comment"

### Priorités
1. Logique de jeu correcte
2. Expérience utilisateur fluide
3. Performance acceptable
4. Interface jolie (nice to have)

## Métriques de succès MVP

- 10 parties complètes jouées par 5 beta-testeurs
- 0 bugs bloquants sur règles de jeu
- Temps de réponse < 200ms pour actions
- Parties multijoueur stables (pas de déconnexions)

## Roadmap post-MVP

### Phase 2: Mobile
- Extraction API REST/GraphQL
- Applications iOS et Android natives
- Synchronisation cross-platform

### Phase 3: Social
- Parties publiques matchmaking
- Système de ranking
- Tournois organisés

### Phase 4: Monétisation (optionnelle)
- Abonnement premium
- Cosmétiques
- Publicité non intrusive

## Risques identifiés

| Risque | Impact | Mitigation |
|--------|--------|------------|
| Complexité règles belote | Élevé | Documentation détaillée RULES.md + validation experts |
| Performance temps réel 4 joueurs | Moyen | Phoenix Channels + tests charge |
| Équilibrage bots | Moyen | Itérations basées retours joueurs |
| Abandon utilisateurs si bugs | Élevé | TDD strict + beta fermée |

## Décisions en attente

Aucune pour l'instant.

## Glossaire

- FFB: Fédération Française de Belote
- Coinche: Variante de la belote avec enchères
- Atout: Couleur choisie valant plus de points
- Pli/Trick: Ensemble de 4 cartes jouées (un tour)
- Donne/Deal: Distribution complète des 32 cartes

---

Version: 1.0
Dernière mise à jour: 30/01/2026
Owner: Christophe Craig
