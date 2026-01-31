# 🚀 Guide de Déploiement Render.com

Ce guide décrit comment déployer Coinchette sur Render.com en environnement staging.

## Prérequis

- Compte GitHub avec le repo Coinchette
- Compte Render.com (gratuit) : https://render.com
- Code pushé sur la branche `main` de GitHub

## Configuration

Le projet utilise **Infrastructure as Code** via `render.yaml`. Tous les services sont préconfigurés.

### Services configurés

1. **PostgreSQL Database** (`coinchette-db`)
   - Type: `pserv` (PostgreSQL service)
   - Plan: `free`
   - Database: `coinchette_prod`
   - User: `coinchette`

2. **Web Service** (`coinchette-staging`)
   - Type: `web` (Docker runtime)
   - Plan: `free`
   - Region: `frankfurt`
   - Port: `10000`
   - Dockerfile: `./Dockerfile`

## Déploiement Initial

### Étape 1 : Connecter le Repository GitHub

1. Se connecter sur https://render.com
2. Cliquer sur **"New +"** → **"Blueprint"**
3. Connecter votre compte GitHub si ce n'est pas déjà fait
4. Sélectionner le repository **coinchette**
5. Render détectera automatiquement `render.yaml`

### Étape 2 : Créer les Services

1. Render affichera les 2 services détectés :
   - `coinchette-db` (PostgreSQL)
   - `coinchette-staging` (Web Service)

2. Cliquer sur **"Apply"** pour créer les services

3. Render va :
   - Créer la base de données PostgreSQL
   - Configurer automatiquement `DATABASE_URL`
   - Générer `SECRET_KEY_BASE`
   - Builder l'image Docker (10-15 minutes)
   - Démarrer le service web

### Étape 3 : Vérifier le Déploiement

1. **Logs de build** : Vérifier que le build Docker réussit
   - Aller sur le service `coinchette-staging`
   - Onglet **"Logs"**
   - Vérifier les étapes :
     ```
     [Builder] Building Dockerfile
     [Builder] => [stage-0] FROM hexpm/elixir:1.19.0...
     [Builder] => [stage-1] Installing dependencies...
     [Builder] => [stage-2] Compiling assets...
     [Builder] => [stage-3] Building release...
     [Builder] Build complete!
     ```

2. **Logs runtime** : Vérifier que Phoenix démarre
   ```
   [runtime] Running migrations...
   [runtime] Starting Phoenix server...
   [runtime] [info] Running CoinchetteWeb.Endpoint...
   ```

3. **URL de l'application** :
   - URL fournie par Render : `https://coinchette-staging.onrender.com`
   - Ouvrir dans un navigateur
   - La homepage devrait s'afficher

### Étape 4 : Vérifier la Database

Les migrations sont exécutées automatiquement au démarrage grâce à `rel/overlays/bin/server`.

Pour vérifier manuellement via le shell Render :

1. Aller sur `coinchette-staging` → **"Shell"**
2. Exécuter :
   ```bash
   /app/bin/coinchette remote
   ```
3. Dans la console Elixir :
   ```elixir
   Coinchette.Repo.query!("SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 5")
   ```

## Déploiements Suivants

Render redéploie automatiquement quand du code est pushé sur `main` :

```bash
git add .
git commit -m "Update feature X"
git push origin main
```

Render détecte le push et :
1. Rebuild l'image Docker
2. Exécute les nouvelles migrations (si présentes)
3. Redémarre le service avec la nouvelle version
4. Zero-downtime deployment

## Variables d'Environnement

Configurées automatiquement via `render.yaml` :

| Variable | Source | Description |
|----------|--------|-------------|
| `DATABASE_URL` | Auto (depuis `coinchette-db`) | URL complète PostgreSQL |
| `SECRET_KEY_BASE` | Auto-généré par Render | Clé secrète Phoenix (64 chars) |
| `PHX_HOST` | Statique | `coinchette-staging.onrender.com` |
| `PHX_SERVER` | Statique | `true` (démarre le serveur) |
| `PORT` | Statique | `10000` |
| `POOL_SIZE` | Statique | `2` (free tier limite) |
| `MIX_ENV` | Statique | `prod` |

### Modifier une variable

Si besoin de modifier une variable :

1. Aller sur `coinchette-staging` → **"Environment"**
2. Modifier la valeur
3. Cliquer **"Save Changes"**
4. Le service redémarre automatiquement

## Debugging

### Build échoue

**Erreur** : `ERROR: failed to solve: process "/bin/sh -c mix deps.get --only prod" did not complete`

**Solution** : Vérifier `mix.exs` et `mix.lock` sont à jour localement

**Erreur** : `npm: command not found` ou `pnpm: command not found`

**Solution** : Le Dockerfile installe Node.js 18 + pnpm. Vérifier la section Node.js installation.

### Runtime échoue

**Erreur** : `** (DBConnection.ConnectionError) connection not available`

**Solution** :
- Vérifier que `coinchette-db` est bien démarré (onglet Events)
- Vérifier `DATABASE_URL` est bien configuré (Environment tab)

**Erreur** : `** (RuntimeError) expected PORT environment variable to be set`

**Solution** : Vérifier `PORT=10000` dans Environment variables

### Migrations ne s'exécutent pas

**Vérifier** : Le fichier `rel/overlays/bin/server` contient :

```bash
#!/bin/sh
cd -P -- "$(dirname -- "$0")"
exec ./coinchette eval "Coinchette.Release.migrate()" && exec ./coinchette start
```

**Si absent** :
1. Exécuter localement : `mix phx.gen.release --docker`
2. Commit et push

## Logs et Monitoring

### Voir les logs en temps réel

1. Dashboard Render → `coinchette-staging` → **"Logs"**
2. Toggle **"Live tail"** ON
3. Les logs apparaissent en temps réel

### Logs utiles

**Phoenix démarré avec succès** :
```
[info] Running CoinchetteWeb.Endpoint with cowboy 2.10.0 at 0.0.0.0:10000 (http)
[info] Access CoinchetteWeb.Endpoint at https://coinchette-staging.onrender.com
```

**Migration exécutée** :
```
[info] == Running 20260130224741 Coinchette.Repo.Migrations.CreateUsers.change/0 forward
[info] == Migrated 20260130224741 in 0.1s
```

**Erreur de connexion DB** :
```
[error] Postgrex.Protocol (#PID<0.123.0>) failed to connect: ** (DBConnection.ConnectionError)
```

## Free Tier Limitations

Le plan gratuit Render.com a quelques limitations :

- **Database** : 1 Go de stockage, 100 connexions max
- **Web Service** :
  - 512 MB RAM
  - CPU partagé
  - Services s'endorment après 15 min d'inactivité
  - Cold start ~30 secondes lors du premier accès

**Important** : Le service staging peut être lent au premier chargement (cold start). C'est normal pour le free tier.

## Passer en Production

Pour un déploiement production avec meilleures performances :

1. Upgrade vers plan **Starter** ($7/mois) :
   - 1 GB RAM
   - Pas de cold start (service toujours actif)
   - Meilleure CPU

2. Upgrade database vers **Starter** ($7/mois) :
   - 1 Go RAM
   - 10 Go stockage
   - Meilleures performances

3. Modifier `render.yaml` :
   ```yaml
   services:
     - type: pserv
       plan: starter  # au lieu de free

     - type: web
       plan: starter  # au lieu de free
   ```

## Support

- **Documentation Render** : https://render.com/docs
- **Community Forum** : https://community.render.com
- **Status Page** : https://status.render.com

## Rollback

En cas de problème avec un déploiement :

1. Aller sur `coinchette-staging` → **"Events"**
2. Trouver le déploiement précédent
3. Cliquer sur **"Redeploy"**
4. Render redémarre l'ancienne version

## Checklist Post-Déploiement

- [ ] Homepage s'affiche correctement
- [ ] Créer un compte utilisateur fonctionne
- [ ] Créer une partie solo fonctionne
- [ ] Créer une partie multijoueur fonctionne
- [ ] Bots jouent automatiquement
- [ ] Scores s'affichent correctement
- [ ] Chat fonctionne (multijoueur)
- [ ] Pas d'erreurs dans les logs Render

---

**Date de création** : 2026-01-31
**Dernière mise à jour** : 2026-01-31
**Version Elixir** : 1.19.0
**Version OTP** : 27.2
**Version Phoenix** : 1.8.3
