# 🚀 Quick Start - Docker + Railway CLI

## 📋 Prerequisites (One-time setup)

```bash
# 1. Install Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop

# 2. Install Railway CLI
curl -fsSL https://railway.app/install.sh | sh

# 3. Verify installations
docker --version
railway --version
```

## 🧪 Test Locally FIRST (Critical!)

### Step 1: Setup Environment
```bash
cd /Users/alexmoore/Development/Solarhub-simpro-hubspot/solar-hub-simpro/one-time-sync/jobs-sync

# Your .env file should already exist with correct values
cat .env
```

### Step 2: Test with 5 Jobs
```bash
# Simple command
make test-5

# Or manually
docker-compose --profile test up job-sync-test
```

**What to check:**
- ✅ "Successfully connected to Simpro"
- ✅ "Successfully connected to HubSpot"
- ✅ "Created HubSpot job" or "Updated HubSpot job"
- ✅ Final stats showing 5 jobs processed

### Step 3: Verify in HubSpot
1. Go to HubSpot
2. Find the 5 jobs that were synced
3. Check:
   - ✅ Job names are correct (not blank)
   - ✅ Invoice percentages are correct (e.g., 8.05%, not 805%)
   - ✅ All fields populated
   - ✅ Dates formatted correctly

### Step 4: Test with 50 Jobs (if Step 2 passed)
```bash
make test-50
```

## 🚂 Deploy to Railway

### Step 1: Login to Railway
```bash
make railway-login
# Opens browser for authentication
```

### Step 2: Link to Project
```bash
make railway-link
# Select your project from the list
```

### Step 3: Stop Current Running Sync
**Important:** Stop the sync currently running on Railway to avoid duplicates!

```bash
# Open Railway dashboard
railway open

# Click on your running deployment
# Click "Stop" or "Remove"
```

### Step 4: Deploy Test Mode (10 jobs)
```bash
make railway-test
```

This sets `MAX_JOBS=10` and deploys.

### Step 5: Monitor Test
```bash
make railway-logs
```

Watch for:
- ✅ Jobs processing
- ✅ No errors
- ✅ Correct data

### Step 6: Deploy Full Sync
**Only do this if test passed!**

```bash
make railway-deploy
```

This removes `MAX_JOBS` limit and starts full sync.

### Step 7: Monitor Full Sync
```bash
# Watch logs
make railway-logs

# Check status
make railway-status
```

## 📊 Monitoring Commands

```bash
# Railway logs (live)
railway logs --follow

# Local logs
tail -f logs/sync_jobs.log

# Railway status
railway status

# Railway dashboard
railway open
```

## 🛑 Stop/Pause Deployment

```bash
# Option 1: Via dashboard
railway open
# Click "Stop" on deployment

# Option 2: Via CLI (SSH in and kill process)
railway ssh
# Then: pkill -f ruby
```

## 🔧 Troubleshooting

### Test fails locally?
```bash
# Check environment variables
cat .env

# Test Docker
docker run hello-world

# Rebuild and try again
make clean
make build
make test-5
```

### Railway deployment fails?
```bash
# Check variables are set
railway variables

# Check logs
railway logs

# Try redeploying
railway redeploy
```

### Wrong data in HubSpot?
```bash
# Stop Railway deployment immediately
railway open
# Click "Stop"

# Fix the issue locally first
make test-5

# Then redeploy
make railway-deploy
```

## 📝 Command Cheat Sheet

```bash
# Local Testing
make test-5          # Test 5 jobs
make test-50         # Test 50 jobs
make run             # Full sync locally
make logs            # View local logs
make clean           # Clean up Docker

# Railway Deployment
make railway-login   # Login to Railway
make railway-link    # Link to project
make railway-test    # Deploy test (10 jobs)
make railway-deploy  # Deploy full sync
make railway-logs    # View Railway logs
make railway-status  # Check status
```

## ⚠️ Important Notes

1. **ALWAYS test locally first** (make test-5)
2. **Verify in HubSpot** before full sync
3. **Stop existing Railway deployment** before new one
4. **Monitor logs** during full sync
5. **Full sync takes ~9-10 hours** for 25,840 jobs

## 🎯 Recommended Workflow

```bash
# 1. Test locally (5 jobs)
make test-5

# 2. Check HubSpot - verify data is correct

# 3. Test locally (50 jobs)
make test-50

# 4. Check HubSpot again

# 5. Login to Railway
make railway-login
make railway-link

# 6. Stop existing deployment (via dashboard)
railway open

# 7. Deploy test to Railway
make railway-test
make railway-logs

# 8. Deploy full sync
make railway-deploy
make railway-logs

# 9. Monitor until complete (~10 hours)
```

## 📞 Need Help?

- Railway docs: https://docs.railway.com/reference/cli-api
- Docker docs: https://docs.docker.com/get-started/
- Check DOCKER_SETUP.md for detailed guide

