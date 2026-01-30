# Règles Officielles - Belote et Coinche

Source: Fédération Française de Belote (FFB)
Référence: https://www.ffbelote.org/regles

## Matériel

### Jeu de cartes
- 32 cartes (7, 8, 9, 10, Valet, Dame, Roi, As)
- 4 couleurs: Pique, Cœur, Carreau, Trèfle
- Pas de Joker

### Joueurs
- 4 joueurs obligatoires
- 2 équipes de 2 joueurs
- Joueurs en face = même équipe
- Positions: Nord, Est, Sud, Ouest

## Déroulement Partie

### 1. Distribution des cartes
- Donneur change à chaque manche dans le sens horaire
- Distribution en 2 fois:
  - 1er tour: 3 cartes par joueur
  - 2ème tour: 2 cartes par joueur
- Reste 3 cartes (le talon)
- Carte retournée du talon = proposition d'atout

### 2. Phase d'enchères (Belote Classique)

#### Premier tour d'enchères
- Commence par joueur à droite du donneur
- Options: "Je prends" ou "Je passe"
- Si "Je prends": couleur retournée devient atout
- Si tous passent: second tour

#### Second tour d'enchères
- Même ordre
- Options: Choisir une autre couleur ou "Je passe"
- Si tous passent: on redistribue

#### Fin des enchères
- Preneur récupère les 3 cartes du talon
- Donneur complète les mains (2 cartes supplémentaires chacun)
- Chaque joueur a 8 cartes finales

### 3. Phase de jeu

#### Ordre de jeu
- Premier pli: joueur à droite du donneur
- Plis suivants: gagnant du pli précédent

#### Obligation de jeu
AVEC ATOUT demandé:
- Fournir l'atout si possible
- Sinon: couper avec atout si possible
- Sinon: surcouper si possible (monter sur partenaire interdit)
- Sinon: défausser n'importe quelle carte

AVEC COULEUR NON-ATOUT demandée:
- Fournir la couleur si possible
- Sinon: couper avec atout si possible
- Sinon: surcouper si possible
- Sinon: défausser

SANS la couleur demandée ET partenaire maître:
- Pas obligation de couper
- Peut défausser librement

#### Gagnant du pli
- Plus forte carte dans la couleur demandée
- OU plus fort atout si coupé

## Valeur des Cartes

### Cartes ATOUT
- Valet (Mistigri): 20 points
- 9: 14 points
- As: 11 points
- 10: 10 points
- Roi: 4 points
- Dame: 3 points
- 8: 0 points
- 7: 0 points

### Cartes NON-ATOUT
- As: 11 points
- 10: 10 points
- Roi: 4 points
- Dame: 3 points
- Valet: 2 points
- 9, 8, 7: 0 points

### Points bonus
- Belote + Rebelote: 20 points (Roi + Dame d'atout joués)
- Dernier pli (Dix de der): 10 points
- Total points par manche: 162 points

## Comptage des Points

### Contrat réussi (preneur)
- Équipe preneuse ≥ 82 points: garde ses points
- Équipe adverse garde ses points
- Points Belote-Rebelote ajoutés à l'équipe qui les a

### Contrat chuté (preneur)
- Équipe preneuse < 82 points
- Équipe adverse prend TOUS les points (162)
- Plus Belote-Rebelote si adverse les a

### Capot (tous les plis)
- Équipe fait capot: 252 points (162 + 90 bonus)
- Adverse: 0 points
- Annule Belote-Rebelote adverse

### Générale
- Une équipe annonce vouloir faire tous les plis AVANT le jeu
- Si réussie: 500 points
- Si échouée: Adverse prend 500 points

## Fin de Partie

- Première équipe à atteindre 1000 points (ou seuil défini)
- Ou nombre de manches prédéfini

## Belote vs Coinche - Différences

### COINCHE (Belote contractuelle)

#### Enchères
- Pas de carte retournée
- Enchères libres: 80, 90, 100, ..., 160
- Annonce couleur d'atout obligatoire
- Possibilité "Coincher" (doubler mise adverse)
- Possibilité "Surcoincher" (quadrupler)

#### Annonces spéciales
- Sans atout: ordre As, 10, Roi, Dame, Valet, 9, 8, 7
- Tout atout: toutes cartes comptent comme atout

#### Comptage
- Contrat = points annoncés (pas 82)
- Si réussi: points réels + contrat
- Si chuté: adverse prend contrat (x2 si coinché, x4 si surcoinché)

#### Points Sans Atout
- As: 19 points
- 10: 10 points
- Roi: 4 points
- Dame: 3 points
- Valet: 2 points
- 9, 8, 7: 0 points
- Total: 258 points

#### Points Tout Atout
- Valet: 14 points
- 9: 9 points
- As: 7 points
- 10: 5 points
- Roi: 3 points
- Dame: 2 points
- 8, 7: 0 points
- Total: 248 points

## Cas Limites et Règles Avancées

### Belote-Rebelote
- Doit être annoncée à voix haute en jouant la 2ème carte
- Oubli d'annonce = perte des 20 points
- Valable même si équipe chute

### Couper le partenaire
- Interdit si on peut fournir la couleur
- Interdit de surcouper le partenaire (sauf si adversaire a coupé entre)

### Erreur de jeu
- En partie réelle: pénalité (perte manche)
- En application: empêcher action invalide

### Ordre des cartes égales
- Première jouée l'emporte
- Important pour atouts de même valeur

## Implémentation Technique - Notes

### Validation moves
- Vérifier TOUTES les règles d'obligation
- Calculer cartes légales AVANT que joueur choisisse
- UI doit griser cartes injouables

### State machine
États: 
- waiting_players
- bidding_round_1
- bidding_round_2
- distributing_talon
- playing
- round_finished
- game_finished

### Calcul scores
- Fonction pure: game_state -> scores
- Recalculable à tout moment
- Historique des manches conservé

### Tests critiques
- Tous cas d'obligation de jeu
- Calcul points avec/sans capot
- Comptage Belote-Rebelote
- Transitions état validées

## Références Externes

- Règles FFB complètes: https://www.ffbelote.org/regles
- Vidéo explicative: https://www.youtube.com/watch?v=... (à ajouter)
- FAQ Coinche: https://www.ffbelote.org/faq-coinche

## Glossaire

- Atout: Couleur choisie valant plus de points
- Couper: Jouer un atout quand on n'a pas la couleur demandée
- Surcouper: Jouer un atout plus fort qu'un atout déjà joué
- Pli/Trick: Ensemble des 4 cartes jouées (un tour)
- Manche/Round: Distribution complète jusqu'à comptage
- Donne/Deal: Action de distribuer les cartes
- Preneur: Joueur ayant choisi l'atout
- Défense: Équipe adverse au preneur
- Capot: Remporter tous les plis
- Dix de der: 10 points bonus du dernier pli

---

Version: 1.0
Dernière validation: 30/01/2026
Validé par: FFB (règles officielles)
