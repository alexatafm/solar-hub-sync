# Railway Deployment Guide - Master Sync V2

**Purpose:** Deploy one-time full re-sync to Railway for production execution  
**Date:** December 8, 2025  
**Version:** 2.0.0

---

## 🎯 Overview

This guide covers deploying the Master Sync V2 script to Railway as a separate one-time job. Railway provides:

- ✅ Reliable cloud execution
- ✅ Better network performance than local
- ✅ Persistent logs
- ✅ Easy monitoring
- ✅ No need to keep local computer running

---

## 📋 Prerequisites

### 1. Railway Account & CLI

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Link to your project (if not already)
railway link
```

### 2. Fresh CSV Export from HubSpot

1. Go to HubSpot → Deals → All Deals
2. Click "Actions" → "Export"
3. Select all columns
4. Download CSV
5. Rename to match format: `hubspot-crm-exports-all-deals-YYYY-MM-DD.csv`

---

## 🚀 Deployment Steps

### Step 1: Prepare the Repository

```bash
cd /path/to/solar-hub-simpro
cd one-time-sync

# Add your fresh CSV export
cp ~/Downloads/hubspot-crm-exports-all-deals-2025-12-08.csv .

# Verify the script is executable
chmod +x master_full_sync_v2.rb

# Test locally first (small batch)
ruby master_full_sync_v2.rb --limit=5 --verbose --csv-file=hubspot-crm-exports-all-deals-2025-12-08.csv

# Commit the CSV and script
git add hubspot-crm-exports-all-deals-2025-12-08.csv master_full_sync_v2.rb
git commit -m "chore: update sync script and CSV for re-sync"
git push origin main
```

### Step 2: Configure Railway Service

**Option A: Using Railway Dashboard**

1. Go to https://railway.app
2. Select your project
3. Create new service (or use existing one-time-sync service)
4. Connect to GitHub repository
5. Set root directory to: `one-time-sync` (if separate service)

**Option B: Using Railway CLI**

```bash
# Create new service for sync
railway service create

# Or select existing service
railway service
```

### Step 3: Set Environment Variables

**Via Railway Dashboard:**

1. Go to your service → Variables
2. Add the following:

```
SIMPRO_TEST_URL=https://solarhub.simprosuite.com/api/v1.0/companies/4
SIMPRO_TEST_KEY_ID=your_simpro_api_key_here
HUBSPOT_ACCESS_TOKEN=your_hubspot_token_here
RAILS_ENV=production
RAILS_LOG_LEVEL=info
```

**Via Railway CLI:**

```bash
railway variables set SIMPRO_TEST_URL="https://solarhub.simprosuite.com/api/v1.0/companies/4"
railway variables set SIMPRO_TEST_KEY_ID="your_key"
railway variables set HUBSPOT_ACCESS_TOKEN="your_token"
railway variables set RAILS_ENV="production"
```

### Step 4: Configure Start Command

**In Railway Dashboard:**

1. Go to Settings → Deploy
2. Set Start Command to:

```bash
cd /app && bundle install && cd one-time-sync && ruby master_full_sync_v2.rb --csv-file=hubspot-crm-exports-all-deals-2025-12-08.csv --verbose
```

**Or for specific options:**

```bash
# Sync first 1000 deals
cd /app && bundle install && cd one-time-sync && ruby master_full_sync_v2.rb --csv-file=hubspot-crm-exports-all-deals-2025-12-08.csv --limit=1000 --verbose

# Sync specific pipeline
cd /app && bundle install && cd one-time-sync && ruby master_full_sync_v2.rb --csv-file=hubspot-crm-exports-all-deals-2025-12-08.csv --pipeline=default --verbose

# Skip line items (faster)
cd /app && bundle install && cd one-time-sync && ruby master_full_sync_v2.rb --csv-file=hubspot-crm-exports-all-deals-2025-12-08.csv --skip-line-items --verbose
```

### Step 5: Deploy

```bash
# Deploy via CLI
railway up

# Or trigger deployment via GitHub push
git push origin main

# Monitor deployment
railway logs --follow
```

---

## 📊 Monitoring During Sync

### Real-Time Log Monitoring

```bash
# Follow logs in real-time
railway logs --follow

# Filter for specific events
railway logs --follow | grep "SUCCESS"
railway logs --follow | grep "ERROR"
railway logs --follow | grep "PROGRESS"
```

### Expected Log Output

```
[2025-12-08 10:15:00] [INFO] ================================================================================
[2025-12-08 10:15:00] [INFO] MASTER FULL DATA SYNC V2 - START
[2025-12-08 10:15:00] [INFO] ================================================================================
[2025-12-08 10:15:00] [INFO] Configuration | csv_file=hubspot-crm-exports-all-deals-2025-12-08.csv | ...
[2025-12-08 10:15:01] [INFO] ✅ Loaded CSV successfully | total_deals=1847 | unique_quotes=1823
[2025-12-08 10:15:01] [INFO] Starting sync: | total_available=1847 | to_sync=1847
[2025-12-08 10:15:05] [PROGRESS] 1/1847 (0.1%) | Remaining: 1846 | ETA: 2h 34m | quote_id=50001
[2025-12-08 10:15:09] [SUCCESS] ✅ Synced successfully | quote_id=50001 | deal_id=12345678 | duration=4.23 | line_items=15 | associations=2
...
```

### Key Metrics to Watch

- **PROGRESS lines:** Show completion percentage and ETA
- **SUCCESS count:** Should be majority of deals
- **ERROR count:** Should be minimal (<5%)
- **SKIP count:** Duplicates and archived deals (expected)
- **NOT_FOUND count:** Deals/quotes that don't exist (expected)

---

## 📥 Retrieving Results After Completion

### Download Log Files

Railway doesn't persist files in the container, but logs are captured. You can:

**Option 1: View in Railway Dashboard**
- Go to your service → Logs
- Copy relevant sections

**Option 2: Save Logs via CLI**
```bash
# Save all logs to file
railway logs > sync_results_$(date +%Y%m%d).log

# Last 1000 lines
railway logs --lines 1000 > sync_results.log
```

**Option 3: Add Log Upload (Optional)**

Modify script to upload logs to S3/GCS at completion:

```ruby
# Add at end of script
if ENV['AWS_ACCESS_KEY_ID']
  # Upload logs to S3
  system("aws s3 cp sync_*.log s3://your-bucket/sync-logs/")
  system("aws s3 cp sync_*_report.csv s3://your-bucket/sync-reports/")
end
```

---

## 🎯 Post-Deployment Verification

### 1. Check Summary in Logs

Look for the final summary section:

```
SYNC SUMMARY REPORT
================================================================================
RESULTS:
  Total Processed:      1847
  ✅ Successful:        1789 (96.9%)
  ❌ Failed:            12 (0.6%)
  ⏭️  Skipped:           38 (2.1%)
  🔍 Not Found:         8 (0.4%)
  📦 Line Items Created: 24523
  🔗 Associations:      3578

PERFORMANCE:
  Total Time:   2h 14m
  Average:      4.37s per deal
  Fastest:      1.23s
  Slowest:      12.45s
  Speed:        824 deals/hour
```

### 2. Spot Check in HubSpot

Randomly select 10-20 deals and verify:

- [ ] All deal properties updated
- [ ] Line items present and correct
- [ ] Discounted prices match simPRO
- [ ] Site association exists
- [ ] Contact/company association exists

### 3. Check for Errors

```bash
# Extract errors from logs
railway logs | grep "ERROR" > errors.txt

# Count error types
railway logs | grep "ERROR" | grep "error_class=" | cut -d'=' -f5 | cut -d' ' -f1 | sort | uniq -c | sort -rn
```

---

## 🔧 Troubleshooting

### Common Railway Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "CSV file not found" | Path incorrect | Ensure CSV is in repo root or one-time-sync folder |
| "Bundle install failed" | Gemfile missing | Ensure you're running from app root |
| "Environment variable not set" | Variables not configured | Check Railway dashboard → Variables |
| "Container restarted" | Timeout or memory limit | Increase Railway plan limits |
| "Deployment failed" | Build error | Check build logs for specific error |

### Railway-Specific Configuration

**Increase Timeout:**

Railway has a default timeout. For long-running syncs:

1. Go to Settings → Deploy
2. Set restart policy to: "Never"
3. This allows the sync to run to completion

**Increase Memory (if needed):**

1. Upgrade Railway plan if hitting memory limits
2. Or run sync in batches with --limit option

---

## 💡 Best Practices

### 1. Test Before Full Sync

Always run a small test first:

```bash
# Test with 10 deals
railway run ruby master_full_sync_v2.rb --limit=10 --verbose

# Check results before proceeding
railway logs | grep "SUMMARY"
```

### 2. Run During Off-Peak Hours

Schedule for:
- Nights or weekends
- When team isn't actively using HubSpot
- When API rate limits are less likely to be hit

### 3. Monitor Actively

- Keep Railway dashboard open
- Watch for errors in real-time
- Be ready to stop if critical issues arise

### 4. Use Batching for Very Large Syncs

If syncing >2,000 deals, consider batching:

```bash
# Batch 1: Deals 0-1000
ruby master_full_sync_v2.rb --start-index=0 --end-index=1000

# Batch 2: Deals 1000-2000
ruby master_full_sync_v2.rb --start-index=1000 --end-index=2000

# Batch 3: Deals 2000+
ruby master_full_sync_v2.rb --start-index=2000
```

---

## 📋 Deployment Checklist

**Before Deployment:**

- [ ] Fresh CSV exported from HubSpot (today's date)
- [ ] CSV added to repository and pushed
- [ ] Test run completed locally (--limit=5)
- [ ] Environment variables set in Railway
- [ ] Start command configured correctly
- [ ] Team notified of upcoming sync
- [ ] Monitoring plan in place

**During Deployment:**

- [ ] Railway logs being monitored
- [ ] Progress percentage increasing
- [ ] Success count growing
- [ ] Error count staying low (<5%)
- [ ] ETA reasonable

**After Deployment:**

- [ ] Summary report reviewed
- [ ] Success rate acceptable (>95%)
- [ ] Spot checks completed in HubSpot
- [ ] Errors analyzed and categorized
- [ ] Log files saved for records
- [ ] Team notified of completion

---

## 🚨 Emergency Stop

If you need to stop the sync:

```bash
# Via CLI
railway service stop

# Or via Dashboard
# Go to service → Settings → Stop Service
```

**To Resume:**

```bash
# Find last successfully synced index from logs
railway logs | grep "SUCCESS" | tail -1

# Update start command with --start-index
# Then redeploy
```

---

## 📈 Expected Results

### For ~1,800 Deals

- **Total Time:** 2-3 hours
- **Success Rate:** 95-98%
- **Line Items:** 20,000-30,000 created
- **Associations:** 3,000-4,000 created
- **Errors:** <50 (mostly network timeouts, expected)
- **Skipped:** 20-50 (duplicates/archived, expected)

---

## 🎉 Success Confirmation

After sync completes successfully:

1. **Save the summary** from logs
2. **Export and review** spot-checked deals
3. **Document any errors** for follow-up
4. **Notify team** of completion
5. **Archive log files** for records
6. **Update tracking** documentation

---

**Prepared By:** Development Team  
**Last Updated:** December 8, 2025  
**Version:** 2.0.0  
**Railway Project:** solar-hub-simpro one-time-sync

