# Deployment Checklist

## ✅ Pre-Deployment Verification

- [x] **CSV file included** in Dockerfile (line 37)
- [x] **Archived deals skipped** - Checks for `closedlost` + `Duplicate - Merged` during sync
- [x] **Duplicate handling** - Default `--duplicates=first` (one deal per quote ID)
- [x] **SimPRO update** - CustomField 229 (HubSpot Deal ID) updated during sync
- [x] **Structured logging** - Railway-optimized logging with tags
- [x] **Error handling** - Clear distinction between handled skips and actual errors
- [x] **Progress tracking** - ETA and progress updates

## 📦 Docker Image Contents

✅ `master_full_sync.rb` - Main sync script  
✅ `hubspot-crm-exports-all-deals-2025-11-28.csv` - Deal export CSV  
✅ All Rails models and dependencies  
✅ Updated quote sync logic  
✅ SimPRO CustomField 229 update logic  

## 🚀 Build Commands

```bash
cd /Users/alexmoore/Development/Solarhub-simpro-hubspot/solar-hub-simpro

# Build Docker image for Railway
docker build --platform linux/amd64 \
  -f one-time-sync/Dockerfile.master_sync \
  -t solar-hub-master-sync:latest \
  .
```

## 📤 Push to Railway

### Option 1: Railway CLI (Recommended)

```bash
# Login
railway login

# Link to project
railway link

# Deploy
railway up
railway deploy
```

### Option 2: Railway Web UI

1. Go to Railway dashboard
2. Create/select service
3. Connect GitHub repo OR upload Docker image
4. Set environment variables
5. Deploy

### Option 3: Docker Hub

```bash
# Tag for Docker Hub
docker tag solar-hub-master-sync:latest <your-dockerhub>/solar-hub-master-sync:latest

# Push
docker push <your-dockerhub>/solar-hub-master-sync:latest

# In Railway, use Docker Hub image URL
```

## 🔧 Environment Variables (Set in Railway)

**Required:**
```
SIMPRO_TEST_URL=https://your-instance.simprosuite.com
SIMPRO_TEST_KEY_ID=your_simpro_api_key
HUBSPOT_ACCESS_TOKEN=your_hubspot_token
```

**Optional:**
```
LIMIT=50                    # Test with 50 deals first
DUPLICATES=first            # One deal per quote ID (default)
PIPELINE_FILTER=default     # Filter by pipeline
```

## 🧪 Test Before Full Sync

```bash
# Test with 50 deals
railway run bundle exec ruby one-time-sync/master_full_sync.rb --limit=50
```

## 📊 What Gets Synced

1. **Loads CSV** - Reads from `hubspot-crm-exports-all-deals-2025-11-28.csv`
2. **Skips Archived** - Automatically skips 517 archived duplicate deals
3. **Syncs ~11,063 deals** (one per unique quote ID)
4. **Updates SimPRO** - Sets CustomField 229 with HubSpot Deal ID
5. **Creates Line Items** - With discounted prices, STCs/VEECs, cost-center ratios

## ⏱️ Expected Duration

- **50 deals**: ~3-5 minutes
- **Full sync**: ~6-8 hours

## 📝 Monitoring

```bash
# View logs
railway logs

# Follow logs
railway logs --follow
```

## ✅ Post-Deployment Verification

1. Check Railway logs for completion summary
2. Verify deals updated in HubSpot
3. Spot-check SimPRO quotes have CustomField 229 updated
4. Confirm archived duplicates were skipped (check logs for `[SKIP] Skipping archived duplicate deal`)

