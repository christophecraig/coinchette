# 💬 PROMPTS - Templates d'Instructions pour Claude

**Usage**: Copy-paste ces prompts pour des tâches récurrentes.  
**Personnalisation**: Remplace `{PLACEHOLDER}` par tes valeurs.

---

## 🚀 Développement

### 1. Implémenter une Nouvelle Feature

\`\`\`
Je veux implémenter {FEATURE_NAME} pour le projet Coinchette.

Contexte:
- Référence TASKS.md : TASK-{NUMBER}
- Dépendances: {MODULES_EXISTANTS}
- Contraintes: {REGLES_FFB_CONCERNEES}

Attentes:
1. Code Elixir idiomatique suivant CONVENTIONS.md
2. Tests unitaires (coverage >90%)
3. Documentation inline (typespecs + @doc)
4. Mise à jour TASKS.md (cocher checklist)

Fournis:
- Le code complet commenté
- Les tests associés
- Un exemple d'utilisation
- Les modifications à faire dans TASKS.md
\`\`\`

**Exemple concret**:
\`\`\`
Je veux implémenter le module Rules pour valider les cartes jouées.

Contexte:
- Référence TASKS.md : TASK-005
- Dépendances: Game (TASK-003), Cards (TASK-004)
- Contraintes: Respect strict RULES.md section 2.4

Attentes:
1. Fonction Rules.valid_card?(game, player, card)
2. Tests exhaustifs (20+ cas de RULES.md)
3. Property tests (carte invalide jamais acceptée)
4. Performance <5ms par validation
\`\`\`

---

### 2. Débugger un Problème

\`\`\`
J'ai un bug dans {MODULE_NAME}.

Symptômes:
- Comportement attendu: {EXPECTED}
- Comportement réel: {ACTUAL}
- Erreur (si applicable): {ERROR_MESSAGE}

Code problématique:
\`\`\`elixir
{PASTE_CODE}
\`\`\`

Tests concernés:
\`\`\`elixir
{PASTE_FAILING_TESTS}
\`\`\`

Analyse et propose:
1. Cause probable du bug
2. Fix avec explication
3. Test supplémentaire pour non-régression
\`\`\`

---

### 3. Refactoring / Amélioration Code

\`\`\`
Je veux refactoriser {MODULE_NAME} car {RAISON}.

Code actuel:
\`\`\`elixir
{PASTE_CODE}
\`\`\`

Objectifs:
- [ ] {OBJECTIF_1} (ex: réduire complexité cyclomatique)
- [ ] {OBJECTIF_2} (ex: améliorer performance)
- [ ] {OBJECTIF_3} (ex: meilleure lisibilité)

Contraintes:
- Tests existants doivent tous passer
- Comportement externe identique
- Pas de régression performance

Propose:
1. Version refactorisée annotée
2. Justification des changements
3. Benchmarks (si perf critique)
\`\`\`

---

### 4. Écrire des Tests

\`\`\`
Génère des tests pour {MODULE_NAME}.{FUNCTION_NAME}

Fonction:
\`\`\`elixir
{PASTE_FUNCTION_CODE}
\`\`\`

Couvre:
1. Cas nominaux (happy path)
2. Cas d'erreur (edge cases)
3. Validations entrées
4. {CAS_SPECIFIQUE_METIER} (si applicable)

Format:
- ExUnit avec describe/test
- Fixtures via setup si nécessaire
- Property tests si logique complexe

Objectif coverage: >90%
\`\`\`

---

## 📐 Architecture & Design

### 5. Valider une Décision Technique

\`\`\`
Je veux valider une décision technique pour {PROBLEME}.

Options considérées:
1. {OPTION_1} - {AVANTAGES} / {INCONVENIENTS}
2. {OPTION_2} - {AVANTAGES} / {INCONVENIENTS}
3. {OPTION_3} - {AVANTAGES} / {INCONVENIENTS}

Contraintes projet:
- Stack: {TECH_STACK}
- Performance: {PERF_REQUIREMENTS}
- Scalabilité: {SCALE_NEEDS}

Analyse et recommande:
1. Meilleure option avec justification
2. Trade-offs acceptables
3. Alternatives futures (si pivot nécessaire)
4. Draft ADR (pour DECISIONS.md)
\`\`\`

---

### 6. Concevoir un Nouveau Module

\`\`\`
Je dois concevoir le module {MODULE_NAME} pour {OBJECTIF}.

Responsabilités:
- {RESPONSABILITE_1}
- {RESPONSABILITE_2}

Interactions:
- Appelé par: {MODULES_PARENTS}
- Appelle: {MODULES_ENFANTS}
- Events PubSub: {EVENTS_SI_APPLICABLE}

Propose:
1. Interface publique (fonctions + specs)
2. Structure de données (structs)
3. Diagramme de séquence (si flux complexe)
4. Checklist implémentation (pour TASKS.md)
\`\`\`

---

## 📝 Documentation

### 7. Documenter une API

\`\`\`
Génère la documentation API pour {MODULE_NAME}.

Code:
\`\`\`elixir
{PASTE_MODULE_CODE}
\`\`\`

Format:
- @moduledoc avec overview
- @doc pour chaque fonction publique
- @spec avec typespecs strictes
- Exemples iex> pour fonctions principales

Audience: Développeurs externes utilisant notre lib
\`\`\`

---

### 8. Créer un Guide Utilisateur

\`\`\`
Rédige un guide utilisateur pour {FEATURE_NAME}.

Audience: {JOUEURS / ADMINS / DEVELOPPEURS}

Structure:
1. Introduction (quoi/pourquoi)
2. Prérequis
3. Étapes détaillées avec captures
4. Cas d'usage courants
5. FAQ / Troubleshooting

Ton: {TECHNIQUE / ACCESSIBLE / TUTORIEL}
Format: Markdown avec emojis
\`\`\`

---

## 🐛 Debugging & Investigation

### 9. Analyser des Logs

\`\`\`
J'ai des logs étranges en production :

\`\`\`
{PASTE_LOGS}
\`\`\`

Contexte:
- Feature concernée: {FEATURE}
- Fréquence: {OCCURENCE}
- Impact utilisateur: {IMPACT}

Analyse:
1. Cause probable
2. Données supplémentaires à logger
3. Fix immédiat (si critique)
4. Solution long terme
\`\`\`

---

### 10. Optimiser Performance

\`\`\`
{MODULE_NAME}.{FUNCTION} est trop lent.

Mesures actuelles:
- Temps moyen: {TIME_MS}ms
- P95: {P95_MS}ms
- Appels/seconde: {RPS}

Code:
\`\`\`elixir
{PASTE_CODE}
\`\`\`

Objectif: <{TARGET_MS}ms

Propose:
1. Analyse bottleneck (profiling)
2. Optimisations possibles (algorithme/caching/DB)
3. Trade-offs (mémoire vs CPU)
4. Benchmarks avant/après
\`\`\`

---

## 🧪 Testing

### 11. Créer des Property Tests

\`\`\`
Génère des property tests pour {PROPRIETE_INVARIANTE}.

Fonction testée:
\`\`\`elixir
{PASTE_FUNCTION}
\`\`\`

Propriétés à vérifier:
- [ ] {PROPRIETE_1} (ex: output toujours trié)
- [ ] {PROPRIETE_2} (ex: pas de doublons)
- [ ] {PROPRIETE_3} (ex: somme = input)

Utilise StreamData pour générer inputs variés.
Runs: 100 minimum
\`\`\`

---

### 12. Tester un Scénario E2E

\`\`\`
Crée un test E2E pour {SCENARIO_UTILISATEUR}.

User story:
En tant que {ROLE}
Je veux {ACTION}
Afin de {BENEFICE}

Steps:
1. {STEP_1}
2. {STEP_2}
3. {STEP_3}

Assertions:
- [ ] {ASSERTION_1}
- [ ] {ASSERTION_2}

Format: Phoenix LiveViewTest
\`\`\`

---

## 📊 Revue de Code

### 13. Review d'une Pull Request

\`\`\`
Review cette PR s'il te plaît :

**Titre**: {PR_TITLE}
**Changements**: {SUMMARY}

\`\`\`diff
{PASTE_DIFF}
\`\`\`

Checklist review:
- [ ] Code suit CONVENTIONS.md
- [ ] Tests ajoutés/modifiés
- [ ] Pas de régression
- [ ] Documentation à jour
- [ ] Pas de secret hardcodé

Feedback structuré:
1. 🟢 Points positifs
2. 🔴 Problèmes bloquants
3. 🟡 Suggestions d'amélioration
\`\`\`

---

## 🔧 Maintenance

### 14. Mettre à Jour les Dépendances

\`\`\`
Analyse l'impact de mettre à jour {DEPENDENCY} vers {NEW_VERSION}.

mix.exs actuel:
\`\`\`elixir
{:dependency, "~> {OLD_VERSION}"}
\`\`\`

Changelog: {LINK_TO_CHANGELOG}

Fournis:
1. Breaking changes identifiés
2. Modifications code nécessaires
3. Plan de migration (si complexe)
4. Risques associés
\`\`\`

---

### 15. Rédiger un ADR

\`\`\`
Rédige une ADR pour {DECISION}.

Contexte:
{DESCRIPTION_PROBLEME}

Options évaluées:
1. {OPTION_1}
2. {OPTION_2}

Décision: {CHOIX_RETENU}

Justification:
{ARGUMENTS}

Utilise le template ADR de DECISIONS.md.
\`\`\`

---

## 🎯 Planification

### 16. Estimer une Tâche

\`\`\`
Estime la complexité de {TASK_DESCRIPTION}.

Détails:
- Objectif: {GOAL}
- Contraintes: {CONSTRAINTS}
- Dépendances: {DEPENDENCIES}

Fournis:
1. Décomposition en sous-tâches
2. Estimation temps (heures)
3. Risques identifiés
4. Prérequis techniques

Format: Checklist TASKS.md
\`\`\`

---

### 17. Prioriser le Backlog

\`\`\`
Aide-moi à prioriser ces features :

1. {FEATURE_1} - {DESCRIPTION}
2. {FEATURE_2} - {DESCRIPTION}
3. {FEATURE_3} - {DESCRIPTION}

Critères:
- Impact utilisateur: {HIGH/MEDIUM/LOW}
- Effort dev: {HOURS}
- Dépendances techniques: {YES/NO}
- Valeur business: {HIGH/MEDIUM/LOW}

Recommande un ordre avec matrice effort/valeur.
\`\`\`

---

## 🤝 Collaboration

### 18. Onboarder un Nouveau Dev

\`\`\`
Génère un plan d'onboarding pour un nouveau dev sur Coinchette.

Profil: {JUNIOR/MID/SENIOR} Elixir

Programme:
- Jour 1: {FOCUS_AREAS}
- Semaine 1: {FIRST_TASKS}
- Mois 1: {OBJECTIVES}

Inclure:
- Lectures obligatoires (.claudefiles/)
- Setup environnement (checklist)
- Première PR suggérée (good first issue)
- Points de contact (qui pour quoi)
\`\`\`

---

## 🔍 Recherche

### 19. Investiguer une Techno

\`\`\`
Je veux utiliser {TECHNOLOGY} pour {USE_CASE}.

Contexte projet:
- Stack actuelle: {CURRENT_STACK}
- Contraintes: {CONSTRAINTS}

Recherche:
1. Compatibilité avec notre stack
2. Exemples d'usage similaires
3. Pros/Cons vs alternatives
4. Effort intégration estimé
5. Communauté/Support

Recommandation: Go/No-Go avec justification
\`\`\`

---

## 📈 Monitoring

### 20. Créer un Dashboard

\`\`\`
Conçois un dashboard de monitoring pour {ASPECT}.

Métriques critiques:
- {METRIC_1}
- {METRIC_2}
- {METRIC_3}

Alertes:
- {CONDITION_ALERTE_1} → {ACTION}
- {CONDITION_ALERTE_2} → {ACTION}

Format:
- Outil: {GRAFANA / DATADOG / CUSTOM}
- Refresh: {INTERVAL}
- Audience: {DEVS / OPS / BUSINESS}
\`\`\`

---

## 💡 Tips d'Utilisation

### Variables Fréquentes à Remplacer

\`\`\`
{MODULE_NAME}     → Ex: "Games.Rules"
{FUNCTION_NAME}   → Ex: "valid_card?"
{TASK_NUMBER}     → Ex: "005"
{FEATURE_NAME}    → Ex: "Système d'enchères"
{ERROR_MESSAGE}   → Copier l'erreur exacte
{PASTE_CODE}      → Code concerné (10-50 lignes max)
\`\`\`

### Bonnes Pratiques

1. **Contexte riche** : Plus de détails = meilleure réponse
2. **Code minimal** : Extrais seulement la partie concernée
3. **Objectif clair** : Spécifie ce que tu attends en output
4. **Contraintes explicites** : Mentionne CONVENTIONS.md, RULES.md

### Chaîner les Prompts

\`\`\`
Prompt 1: Conception (Template 6)
   ↓
Prompt 2: Implémentation (Template 1)
   ↓
Prompt 3: Tests (Template 4)
   ↓
Prompt 4: Review (Template 13)
\`\`\`

---

## 🆕 Ajouter un Nouveau Prompt

\`\`\`markdown
### XX. {TITRE_PROMPT}

\`\`\`
{TEMPLATE_AVEC_PLACEHOLDERS}
\`\`\`

**Exemple concret**:
\`\`\`
{EXEMPLE_REMPLI}
\`\`\`

**Quand l'utiliser**: {USE_CASE}
\`\`\`

---

**Version**: 1.0  
**Contributions**: Ajoute tes prompts récurrents ici !  
**Feedback**: Si un prompt ne marche pas bien, adapte-le
