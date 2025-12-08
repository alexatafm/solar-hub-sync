# Railway Deployment Guide

## Prerequisites

1. **Railway CLI installed** (optional, can use web UI)
2. **Docker installed** (for local testing)
3. **CSV file included** in Docker image

## Docker Image Contents

✅ All sync logic (`master_full_sync.rb`)  
✅ CSV file (`hubspot-crm-exports-all-deals-2025-11-28.csv`)  
✅ Rails environment and dependencies  
✅ Updated quote sync logic with discounted prices  
✅ SimPRO CustomField 229 update (HubSpot Deal ID)  
✅ Archived duplicate deal skipping  

## Build Docker Image

```bash
cd /Users/alexmoore/Development/Solarhub-simpro-hubspot/solar-hub-simpro

# Build for Railway (linux/amd64 platform)
docker build --platform linux/amd64 \
  -f one-time-sync/Dockerfile.master_sync \
  -t solar-hub-master-sync:latest \
  .
```

## Deploy to Railway

### Option 1: Railway CLI

```bash
# Login to Railway
railway login

# Initialize Railway project (if not already done)
railway init

# Link to existing service (if you have one)
railway link

# Deploy
railway up
railway deploy
```

### Option 2: Railway Web UI

1. Go to Railway dashboard
2. Create new service or select existing
3. Connect GitHub repo OR upload Docker image
4. Set environment variables (see below)
5. Deploy

### Option 3: Docker Hub + Railway

```bash
# Tag and push to Docker Hub
docker tag solar-hub-master-sync:latest <your-dockerhub>/solar-hub-master-sync:latest
docker push <your-dockerhub>/solar-hub-master-sync:latest

# In Railway, use the Docker Hub image URL
```

## Required Environment Variables

Set these in Railway dashboard:

```
SIMPRO_TEST_URL=https://your-instance.simprosuite.com
SIMPRO_TEST_KEY_ID=your_simpro_api_key
HUBSPOT_ACCESS_TOKEN=your_hubspot_token
```

## Optional Environment Variables

```
# CSV file path (default: hubspot-crm-exports-all-deals-2025-11-28.csv)
CSV_FILE=hubspot-crm-exports-all-deals-2025-11-28.csv

# Limit number of deals to sync (for testing)
LIMIT=50

# Start from specific index
START_INDEX=0

# End at specific index
END_INDEX=100

# Pipeline filter
PIPELINE_FILTER=default

# Duplicate handling (first, all, skip)
DUPLICATES=first
```

## Command Line Arguments

The sync script accepts these arguments:

```bash
--csv-file=FILE          # CSV file path
--start-index=N          # Start from index N
--end-index=N            # End at index N
--limit=N                # Limit to N deals
--pipeline=PIPELINE      # Filter by pipeline
--duplicates=MODE        # Handle duplicates: first, all, skip
--dry-run                # Preview without syncing
--verbose                # Detailed logging
```

## Example Railway Commands

### Full Sync
```bash
railway run bundle exec ruby one-time-sync/master_full_sync.rb
```

### Test with 50 Deals
```bash
railway run bundle exec ruby one-time-sync/master_full_sync.rb --limit=50
```

### Dry Run
```bash
railway run bundle exec ruby one-time-sync/master_full_sync.rb --dry-run --limit=10
```

## Monitoring

### View Logs
```bash
railway logs
```

### Follow Logs
```bash
railway logs --follow
```

## What Happens During Sync

1. **Loads CSV** - Reads deals from `hubspot-crm-exports-all-deals-2025-11-28.csv`
2. **Skips Archived** - Automatically skips deals archived as "Duplicate - Merged"
3. **Handles Duplicates** - Uses `--duplicates=first` by default (one deal per quote ID)
4. **Syncs Each Deal**:
   - Fetches quote from SimPRO with `display=all`
   - Updates deal properties
   - Creates/updates line items with discounted prices
   - Updates SimPRO CustomField 229 with HubSpot Deal ID
5. **Logs Progress** - Elegant structured logging for Railway observability

## Expected Duration

- **50 deals**: ~3-5 minutes
- **500 deals**: ~30-45 minutes  
- **Full sync (11,063 deals)**: ~6-8 hours

## Troubleshooting

### CSV File Not Found
- Ensure CSV is copied into Docker image (check Dockerfile)
- Verify CSV path in container: `/app/one-time-sync/hubspot-crm-exports-all-deals-2025-11-28.csv`

### Rate Limiting
- Script includes automatic rate limiting (0.5s between deals)
- If hitting limits, reduce `--limit` or add delays

### Memory Issues
- Railway provides adequate memory for sync
- If issues occur, sync in smaller batches using `--limit`

## Verification

After sync completes:
1. Check Railway logs for summary
2. Verify deals updated in HubSpot
3. Check SimPRO quotes have CustomField 229 updated
4. Confirm archived duplicates were skipped

