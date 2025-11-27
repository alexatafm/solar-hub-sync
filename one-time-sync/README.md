# One-Time Sync Project

This folder contains the standalone Docker-based sync project for performing bulk line item syncs from Simpro quotes to HubSpot deals.

## Contents

### Core Files
- `standalone_sync.rb` - Final production version of the sync script
- `Dockerfile.sync` - Docker configuration for Railway deployment
- `hubspot-crm-exports-all-deals-2025-11-21.csv` - Source CSV with HubSpot deal IDs and Simpro quote IDs
- `logs.csv` - Output logs from completed sync run

### Previous Versions (Archive)
- `standalone_sync_v1.1.rb` - Previous version
- `standalone_sync_working.rb` - Earlier working version
- `standalone_sync_simple.rb` - Initial simple version

### Testing & Development Files
- `test_railway_function.rb` - Railway function testing
- `test_optimized_sync.rb` - Performance optimization testing
- `bulk_sync_100_deals.rb` - 100-deal test batch script
- `compare_sync_performance.rb` - Performance comparison script
- `sync_line_items_from_csv.rb` - Early CSV sync implementation

### Railway Deployment
- `railway.toml` - Railway configuration
- `railway_sync_function.rb` - Railway-specific function
- `railway_sync_20251121_152232.log` - Deployment log
- `RAILWAY_FUNCTION_CODE.txt` - Railway function code reference

## Sync Results Summary

**Total Processed:** 11,582 deals  
**Successful:** 10,538 (91.0%)  
**Failed:** 1 (0.01%)  
**Skipped:** 1,043 (9.0%)  
**Line Items Created:** 75,614  
**Total Time:** 9h 5m  
**Average:** 3.04s per deal  

## Deployment

See `../docs/RAILWAY_DEPLOYMENT_STEPS.md` for deployment instructions.

## Environment Variables Required

```
SIMPRO_URL=https://your-instance.simprosuite.com
SIMPRO_API_KEY=your_api_key
HUBSPOT_TOKEN=your_token
```

## Usage

### Local Testing
```bash
docker build -f Dockerfile.sync -t hubspot-sync .
docker run --env-file .env.docker hubspot-sync
```

### Railway Deployment
```bash
docker build --platform linux/amd64 -f Dockerfile.sync -t afmservices/hubspot-sync:latest .
docker push afmservices/hubspot-sync:latest
```

Then deploy on Railway dashboard with environment variables configured.

