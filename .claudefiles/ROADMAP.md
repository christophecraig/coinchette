# 🗺️ Roadmap Coinchette

**Horizon** : 12 mois  
**Approche** : Itérative, validation à chaque milestone

---

## 🎯 Vue d'ensemble

```
Phase 1 (MVP)      Phase 2 (V1)       Phase 3 (V2)
│                  │                  │
├─ M1: Setup       ├─ M4: Multi       ├─ M7: Mobile
├─ M2: Solo        ├─ M5: Ranked      ├─ M8: Tournois
├─ M3: PvP local   ├─ M6: Coinche     ├─ M9: Saisons
│                  │                  │
└─ 3 mois          └─ 4 mois          └─ 5 mois
```

---

## 📅 Phase 1 : MVP (Mois 1-3)

### Objectif
Valider le core gameplay et l'architecture technique

### Milestones

#### M1 : Infrastructure & Setup (Semaines 1-2)
**Livrables** :
- [ ] Projet Phoenix initialisé
- [ ] Base de données PostgreSQL configurée
- [ ] CI/CD GitHub Actions
- [ ] Tests E2E avec Playwright
- [ ] Déploiement Fly.io staging

**Critères de succès** :
- Pipeline CI/CD 100% vert
- Temps de build < 5min
- Coverage > 80%

**Risques** :
- 🟡 Complexité WebSocket : Mitigation = PoC early
- 🟢 Setup infra : Faible risque

---

#### M2 : Mode Solo vs IA (Semaines 3-6)
**Livrables** :
- [ ] Moteur de jeu belote classique
- [ ] IA basique (règles + scoring)
- [ ] Interface web responsive
- [ ] Animations cartes fluides

**User Stories** :
```gherkin
Scenario: Partie solo complète
  Given je lance une partie solo
  When je joue 8 donnes
  Then je vois le score final
  And je peux rejouer
```

**Métriques** :
- Temps de partie < 10min
- 0 bug critique sur règles
- Feedback positif 3 utilisateurs pilotes

**Risques** :
- 🟡 Qualité IA : Itérations nécessaires
- 🟢 Règles : Bien documentées (RULES.md)

---

#### M3 : PvP Local (Semaines 7-12)
**Livrables** :
- [ ] Mode 2 joueurs (local)
- [ ] Système d'annonces
- [ ] Chat basique
- [ ] Historique des parties

**Critères de succès** :
- 10 parties complètes jouées sans bug
- Latence annonces < 100ms
- UX fluide (tests utilisateurs)

**Risques** :
- 🟠 Synchro temps réel : Tests de charge nécessaires
- 🟢 Chat : Feature simple

---

## 📅 Phase 2 : Version 1 (Mois 4-7)

### Objectif
Expérience multi-joueurs complète et monétisation

### Milestones

#### M4 : Multijoueur en ligne (Semaines 13-18)
**Livrables** :
- [ ] Matchmaking 4 joueurs
- [ ] Salons privés + publics
- [ ] Gestion déconnexions/reconnexions
- [ ] Spectateurs (mode observateur)

**Stack technique** :
- Phoenix Channels (WebSocket)
- Presence tracking
- PubSub pour broadcast

**Métriques** :
- < 5s pour trouver partie
- Taux abandon < 10%
- Gestion 100 joueurs simultanés

**Risques** :
- 🔴 Scalabilité : Load testing impératif
- 🟡 Abandon parties : Système de pénalités à prévoir

---

#### M5 : Mode Ranked + Progression (Semaines 19-22)
**Livrables** :
- [ ] Système ELO
- [ ] Ligues (Bronze → Diamant)
- [ ] Profils joueurs (stats, badges)
- [ ] Leaderboards temps réel

**Critères de succès** :
- 50 joueurs actifs en ranked
- Équilibrage matchmaking fonctionnel
- Retention J7 > 40%

**Risques** :
- 🟡 Triche/boosting : Détection basique à implémenter
- 🟢 Gamification : Mécaniques éprouvées

---

#### M6 : Mode Coinche (Semaines 23-28)
**Livrables** :
- [ ] Règles coinche complètes
- [ ] Système d'enchères
- [ ] Scoring spécifique
- [ ] IA coinche améliorée

**Complexité** : 🔴 **Élevée**
- Règles plus complexes (RULES.md §3-4)
- Stratégie IA à revoir
- Tests exhaustifs nécessaires

**Risques** :
- 🔴 Bugs règles : Beta test 2 semaines
- 🟡 Balance gameplay : Ajustements post-launch

---

## 📅 Phase 3 : Version 2 (Mois 8-12)

### Objectif
Croissance et engagement long terme

#### M7 : Application Mobile (Semaines 29-36)
**Livrables** :
- [ ] PWA optimisée mobile
- [ ] Notifications push
- [ ] Mode hors ligne (vs IA)
- [ ] App stores (iOS/Android)

**Tech** :
- LiveView Native (si mature) OU
- PWA + capacités natives

**Risques** :
- 🟡 Perf mobile : Optimisations requises
- 🟢 PWA : Technologie éprouvée

---

#### M8 : Tournois (Semaines 37-42)
**Livrables** :
- [ ] Tournois à élimination
- [ ] Système d'inscription
- [ ] Dotations (badges, cosmétiques)
- [ ] Calendrier tournois

**Métriques** :
- 1 tournoi/semaine avec 32+ joueurs
- Taux de complétion > 70%

---

#### M9 : Saisons & Contenu (Semaines 43-52)
**Livrables** :
- [ ] Saisons trimestrielles
- [ ] Battle Pass gratuit
- [ ] Événements thématiques
- [ ] Customisation (avatars, cartes)

**Monétisation** :
- Battle Pass premium : 4,99€
- Cosmétiques : 0,99€ - 2,99€
- Objectif : 5€ ARPU/mois

---

## 📊 Métriques globales

### KPIs Phase 1 (MVP)
- **MAU** : 100 utilisateurs
- **Retention J7** : 30%
- **Bugs critiques** : 0
- **Uptime** : > 99%

### KPIs Phase 2 (V1)
- **MAU** : 1000 utilisateurs
- **Retention J7** : 40%
- **Parties/jour** : 50+
- **NPS** : > 40

### KPIs Phase 3 (V2)
- **MAU** : 5000 utilisateurs
- **ARPU** : 5€/mois
- **Retention J30** : 25%
- **Tournois actifs** : 4/mois

---

## 🚨 Gestion des risques

### Risques techniques
| Risque | Impact | Probabilité | Mitigation |
|--------|--------|-------------|------------|
| Scalabilité WebSocket | 🔴 | Moyen | Load tests M4, architecture distribuée |
| Bugs règles coinche | 🔴 | Élevé | Beta test 2 semaines, tests exhaustifs |
| Perf mobile | 🟡 | Moyen | Profiling early, optimisations progressive |

### Risques produit
| Risque | Impact | Probabilité | Mitigation |
|--------|--------|-------------|------------|
| Faible adoption | 🔴 | Moyen | Marketing ciblé, beta testeurs engagés |
| Triche/abus | 🟡 | Élevé | Détection basique M5, amélioration continue |
| Abandon parties | 🟡 | Élevé | Pénalités, incentives completion |

---

## 🔄 Processus de validation

### Chaque milestone :
1. **Planning** : Découpage tâches (TASKS.md)
2. **Développement** : Itérations hebdomadaires
3. **Testing** : QA + tests utilisateurs
4. **Review** : Démo + rétrospective
5. **Déploiement** : Staging → Production

### Critères de passage :
- ✅ Tous les critères de succès atteints
- ✅ 0 bug bloquant
- ✅ Tests > 80% coverage
- ✅ Documentation à jour

---

## 📝 Notes

- **Flexibilité** : Ajustements possibles selon feedback utilisateurs
- **Priorisation** : Features non-critiques peuvent être reportées
- **Tech debt** : 20% du temps alloué au refactoring
- **Documentation** : Maintenue en continu (pas de phase dédiée)

**Dernière mise à jour** : 2026-01-30
