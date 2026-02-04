# Running Database Migrations on Render.com

## Migration Created

**File:** `priv/repo/migrations/20260204012428_add_multi_round_support_to_games.exs`

This migration adds:
- `target_score` (integer, default: 1000)
- `round_number` (integer, default: 1)

## Option 1: Via Render Dashboard (Recommended)

1. **Navigate to your service:**
   - Go to https://dashboard.render.com
   - Select your Coinchette web service

2. **Open Shell:**
   - Click on the "Shell" tab in the left sidebar
   - This opens a terminal connected to your running service

3. **Run migration:**
   ```bash
   /app/bin/coinchette eval "Coinchette.Release.migrate()"
   ```

4. **Verify:**
   - Check for "Migrated" success message
   - Should show: `[info] == Migrated 20260204012428 in X.Xs`

## Option 2: Via Render.yaml Deploy Hook (Automated)

If you have a `render.yaml` with a `release` command, migrations run automatically on deploy.

Check your `render.yaml` for:
```yaml
services:
  - type: web
    ...
    buildCommand: mix deps.get --only prod && mix assets.deploy && mix compile
    startCommand: /app/bin/coinchette start
    preDeployCommand: /app/bin/coinchette eval "Coinchette.Release.migrate()"
```

If `preDeployCommand` is configured, migrations run automatically before each deployment.

## Option 3: Manual Deployment with Migration

1. **Push your changes to Git:**
   ```bash
   git add .
   git commit -m "Add multi-round gameplay support"
   git push origin main
   ```

2. **Render auto-deploys:**
   - If auto-deploy is enabled, Render detects the push
   - Builds new image
   - Runs migrations via `preDeployCommand`
   - Deploys new version

3. **Monitor deployment:**
   - Watch the deployment logs in Render dashboard
   - Look for migration success messages

## Option 4: Using /setup-db-migrations Route (If Available)

Based on recent commits, there's a `/setup-db-migrations` route:

1. **Access the route:**
   ```
   https://your-app.onrender.com/setup-db-migrations
   ```

2. **This should trigger migrations** without shell access

⚠️ **Security Warning:** This route should be removed or protected in production!

## Verifying Migration Success

After running migration, verify in the Shell:

```bash
# Connect to database
/app/bin/coinchette remote

# In IEx console:
alias Coinchette.Repo
alias Coinchette.Multiplayer.Game

# Check schema
Repo.one(from g in Game, select: g, limit: 1)
# Should show target_score and round_number fields

# Exit IEx
Ctrl+C, Ctrl+C
```

Or check via SQL:

```bash
# In Render Shell
psql $DATABASE_URL -c "\d games"
# Should show target_score and round_number columns
```

## Rollback (If Needed)

If migration causes issues:

```bash
/app/bin/coinchette eval "Coinchette.Release.rollback(Coinchette.Repo, 1)"
```

## Common Issues

### Issue: "relation 'games' already has column 'target_score'"

**Solution:** Migration already ran. Check:
```bash
psql $DATABASE_URL -c "SELECT target_score, round_number FROM games LIMIT 1;"
```

### Issue: Migration fails with timeout

**Solution:** Increase migration timeout in `config/runtime.exs`:
```elixir
config :coinchette, Coinchette.Repo,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  migration_lock_timeout: 600_000  # 10 minutes
```

### Issue: Database not accessible

**Solution:** Check DATABASE_URL environment variable is set in Render dashboard.

## Post-Migration Checks

1. **Create a test game:**
   - Log in to your app
   - Create a new game
   - Verify target_score selector shows 500/1000 options

2. **Check database:**
   ```sql
   SELECT id, target_score, round_number, scores
   FROM games
   ORDER BY inserted_at DESC
   LIMIT 5;
   ```

3. **Test gameplay:**
   - Start a game with 500 point target
   - Play through first round
   - Verify new round starts automatically
   - Check cumulative scores display correctly

## Need Help?

If migration fails:
1. Check Render deployment logs
2. Check database logs in Render dashboard
3. Try accessing Shell and running migration manually
4. Contact Render support if database access issues
