# Railway Setup Instructions

## ⚠️ IMPORTANT: Connect to SEPARATE Sync Repository

Railway must connect to the **SEPARATE sync repository**: `alexatafm/solar-hub-sync`

This keeps the sync deployment completely isolated from the production Rails app.

---

## 🔗 Step 1: Connect Repository

In the Railway "Connect Repo" dialog (from your screenshot):

**SELECT:** `alexatafm/solar-hub-sync` ✅

**DO NOT SELECT:** `FileroomProjects/solar-hub-simpro` ❌

### Why This Works:

1. **Complete Isolation:** The sync runs in a separate Railway service, can't affect production
2. **Automatic Model Access:** The Dockerfile clones the main Rails app (public repo) during build
3. **Independent Deployment:** You can deploy, test, and iterate without touching production
4. **Clean Separation:** Production app never knows about the sync repository

### How the Dockerfile Works:

```dockerfile
# 1. Clone main Rails app (gets all models)
RUN git clone --depth 1 https://github.com/FileroomProjects/solar-hub-simpro.git /app

# 2. Install gems from main app
RUN bundle install --without development test

# 3. Copy sync script from THIS repo (solar-hub-sync)
COPY master_full_sync_v2.rb ./one-time-sync/
COPY hubspot-crm-exports-all-deals-2025-11-28.csv ./one-time-sync/

# 4. Run with full Rails context
ENTRYPOINT ["bundle", "exec", "ruby", "one-time-sync/master_full_sync_v2.rb"]
```

This way:
- ✅ Production is never touched
- ✅ Sync has access to all Rails models
- ✅ Completely separate deployments
- ✅ No risk to production app

---

## ⚙️ Step 2: Configure Build Settings

After connecting to `alexatafm/solar-hub-sync`:

### Build → Builder
**Value:** `Dockerfile`

### Build → Dockerfile Path
**Value:** `Dockerfile` (root of the repo)

Railway will use the Dockerfile at the root of the solar-hub-sync repository.

---

## 🚀 Step 3: Configure Deploy Settings

### Deploy → Start Command
```bash
bundle exec ruby one-time-sync/master_full_sync_v2.rb --verbose
```

### Deploy → Restart Policy
**Value:** `Never`

### Deploy → Watch Patterns (Optional)
```
one-time-sync/**
```

This only triggers rebuilds when files in `one-time-sync/` change.

---

## 🔐 Step 4: Set Environment Variables

Go to: **Variables** tab

### Required:
```bash
SIMPRO_TEST_URL=https://solarhub.simprosuite.com/api/v1.0/companies/4
SIMPRO_TEST_KEY_ID=your_api_key_here
HUBSPOT_ACCESS_TOKEN=your_token_here
RAILS_ENV=production
SECRET_KEY_BASE=any_random_string
GITHUB_TOKEN=ghp_your_github_personal_access_token
```

**⚠️ Important:** `GITHUB_TOKEN` is required to clone the private `FileroomProjects/solar-hub-simpro` repository.

#### How to Create GitHub Personal Access Token:

1. **Go to:** https://github.com/settings/tokens
2. **Click:** "Generate new token (classic)"
3. **Name:** `Railway Sync Deployment`
4. **Expiration:** No expiration (or 1 year+)
5. **Scopes:** Check `repo` (Full control of private repositories)
6. **Generate** and copy the token (starts with `ghp_`)
7. **Add to Railway** Variables tab: `GITHUB_TOKEN=ghp_...`

**Note:** The token is only used during Docker build to clone the repo. It's not stored in the final image.

---

## ✅ Step 5: Verify Configuration

### railway.toml (already configured)
```toml
[build]
builder = "dockerfile"
dockerfilePath = "Dockerfile"

[deploy]
restartPolicyType = "never"
```

### Repository Structure
```
alexatafm/solar-hub-sync/
├── Dockerfile ← Railway uses this
├── master_full_sync_v2.rb
├── hubspot-crm-exports-all-deals-2025-11-28.csv
├── railway.toml
├── RAILWAY_SETUP.md
└── ... (documentation files)
```

---

## 📋 Deployment Flow

1. **Railway connects to:** `alexatafm/solar-hub-sync` (separate sync repo)
2. **Railway clones:** The sync repo (script, CSV, config)
3. **Dockerfile clones:** Main Rails app from `FileroomProjects/solar-hub-simpro`
4. **Dockerfile installs:** Gems from main Rails `Gemfile`
5. **Dockerfile copies:** Sync script and CSV into cloned Rails app
6. **Railway runs:** `bundle exec ruby one-time-sync/master_full_sync_v2.rb --verbose`
7. **Script accesses:** Rails models via `require_relative '../config/environment'`

---

## 🔒 Why This is Safe

- **Production Isolation:** Production Rails app is never touched by Railway
- **Read-Only Access:** Dockerfile only reads (clones) the public Rails repo
- **Independent Deployment:** Sync can be deployed/tested without affecting production
- **No Production Risk:** Even if sync crashes, production is unaffected

---

## ✅ Summary

| Setting | Value |
|---------|-------|
| **Repository** | `alexatafm/solar-hub-sync` ✅ |
| **Dockerfile Path** | `Dockerfile` |
| **Start Command** | (Handled by Dockerfile ENTRYPOINT) |
| **Restart Policy** | `never` |
| **Environment** | Set all required variables in Railway Dashboard |

**Select `alexatafm/solar-hub-sync` from the dropdown and Railway will deploy successfully!** 🎉

This keeps your sync completely separate and safe from production! 🔒

