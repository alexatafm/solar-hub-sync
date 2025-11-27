# Solar Hub Simpro HubSpot Sync

One-time sync script for syncing Simpro quotes to HubSpot deals.

## Setup

1. Set environment variables:
   - `SIMPRO_TEST_URL` = `https://solarhub.simprosuite.com/api/v1.0`
   - `SIMPRO_TEST_KEY_ID` = (your Simpro API key)
   - `HUBSPOT_ACCESS_TOKEN` = (your HubSpot access token)
   - `RAILS_ENV` = `production`
   - `SECRET_KEY_BASE` = (any random string)
   - `RUBY_DEBUG_SKIP` = `1`

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Run sync:
   ```bash
   ruby one-time-sync/master_full_sync.rb --verbose
   ```

## Railway Deployment

This repo is configured for Railway deployment via GitHub:
- Connect this repo to Railway
- Set environment variables in Railway dashboard
- Railway will auto-detect and deploy

## Files

- `one-time-sync/master_full_sync.rb` - Main sync script
- `one-time-sync/hubspot-crm-exports-all-deals-2025-11-28.csv` - CSV data source

