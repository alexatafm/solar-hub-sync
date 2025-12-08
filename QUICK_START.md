# Quick Start Guide - Master Data Sync

**Time to complete:** 15-30 minutes for testing, 1-2 hours for full sync

---

## Step 1: Pre-Flight Check (5 minutes)

Verify environment is ready:

```bash
cd /Users/alexmoore/Development/Solarhub-simpro-hubspot/solar-hub-simpro/one-time-sync

# Run automated tests
./test_sync_locally.sh
```

**Expected output:**
```
✅ SIMPRO_TEST_URL: https://newdata.simpro.com.au/...
✅ SimPRO API working - Found 1234 quotes
✅ HubSpot API working
✅ Deal property exists: simpro_quote_id
✅ Deal property exists: simpro_net_price_inc_tax
... (all checks pass)
```

**If anything fails:** Stop and fix the issue before continuing.

---

## Step 2: Dry Run (2 minutes)

Test the sync logic without making changes:

```bash
ruby master_full_sync.rb --dry-run --verbose --end-page=1
```

**What this does:**
- Fetches 1 page of quotes from simPRO
- Processes the data
- Shows what WOULD be synced
- Makes NO changes to HubSpot

**Expected output:**
```
[2025-11-25 15:30:00] [INFO] ========================================
[2025-11-25 15:30:00] [INFO] MASTER FULL DATA SYNC - START
[2025-11-25 15:30:00] [INFO] ========================================
[2025-11-25 15:30:00] [WARN] DRY RUN MODE - No actual changes will be made
...
[2025-11-25 15:30:15] [INFO] Total Quotes Processed: 50
```

---

## Step 3: Small Test Sync (10-15 minutes)

Sync just 5 pages (250 quotes) to verify everything works:

```bash
ruby master_full_sync.rb --start-page=1 --end-page=5 --verbose
```

**What this does:**
- ✅ Syncs 250 quotes (5 pages × 50 quotes)
- ✅ Syncs all customers, sites, deals, line items
- ✅ Takes ~15-25 minutes
- ✅ Creates real data in HubSpot

**Monitor progress:**
```
[2025-11-25 15:35:00] [INFO] Processing Quote 1/50: 50123 - Test Quote
[2025-11-25 15:35:03] [INFO] ✅ Quote synced successfully
[2025-11-25 15:35:04] [INFO] Processing Quote 2/50: 50124 - Another Quote
...
```

**Check HubSpot:**
1. Go to Deals
2. Filter by recent created date
3. Verify ~250 new/updated deals
4. Open a random deal
5. Check line items tab
6. Verify totals match simPRO

---

## Step 4: Verify Results (5 minutes)

### Quick Verification

**In HubSpot:**
1. **Check Deal Count:**
   - Go to Deals
   - Count should increase by ~250

2. **Check Random Deal:**
   - Open any synced deal
   - Verify `simPRO Quote ID` populated
   - Check `Net Price (Inc Tax)` has value
   - Check `Final Total After STCs` has value

3. **Check Line Items:**
   - Open line items tab
   - Should see all quote items
   - Check `Discounted Price (Inc Tax)` populated
   - Sum should match deal's Final Total

4. **Check Associations:**
   - Deal → Contact/Company (should exist)
   - Deal → Site (should exist)
   - Deal → Line Items (should exist)

### Compare with simPRO

Pick a random quote ID from HubSpot:
1. Find quote in simPRO
2. Compare totals:
   - Net Price matches?
   - Discounts match?
   - STCs match?
   - Final total matches?

---

## Step 5: Full Production Sync (1-2 hours)

If small test passed, run full sync:

```bash
# Option A: Run locally (recommended for first time)
ruby master_full_sync.rb --verbose

# Option B: Run in background (if you want to close terminal)
nohup ruby master_full_sync.rb --verbose > sync_output.log 2>&1 &

# Check progress
tail -f sync_output.log
```

**What this does:**
- Syncs ALL quotes from simPRO
- Typically 1,000-2,000 quotes
- Takes 1-2 hours
- Creates/updates all deals, line items, customers, sites

**Monitor:**
```bash
# Watch the log file
tail -f sync_*.log

# Check summary periodically
grep "Processed:" sync_*.log
```

---

## Step 6: Post-Sync Validation (10 minutes)

After sync completes, verify results:

### 1. Check Summary Output

```
SYNC SUMMARY
Total Time: 5432.15 seconds
Customers:
  ✅ Synced: 1234
  ❌ Failed: 5
Deals:
  ✅ Synced: 1850
  ❌ Failed: 12
Line Items:
  ✅ Synced: 28,500
  ❌ Failed: 45
```

### 2. Verify in HubSpot

**Deals:**
- Total count should match sync summary
- Random spot-check 10 deals
- Verify financial totals

**Line Items:**
- Check 5 random deals
- Verify line item counts
- Check discounted price sums

**Associations:**
- Verify contacts linked to deals
- Verify sites linked to deals

### 3. Check for Failed Items

```bash
# Find errors in log
grep "ERROR" sync_*.log

# Count failed items
grep "❌" sync_*.log | wc -l
```

**If failures < 1%:** Acceptable, document and move on  
**If failures > 1%:** Investigate pattern, fix, re-sync failed items

---

## Common Commands Reference

```bash
# Full sync with verbose logging
ruby master_full_sync.rb --verbose

# Resume from page 42 (if interrupted)
ruby master_full_sync.rb --start-page=42 --verbose

# Sync pages 1-10 only
ruby master_full_sync.rb --start-page=1 --end-page=10 --verbose

# Larger page size (faster)
ruby master_full_sync.rb --page-size=250 --verbose

# Dry run (no changes)
ruby master_full_sync.rb --dry-run --verbose

# Get help
ruby master_full_sync.rb --help
```

---

## Troubleshooting Quick Fixes

### "Missing environment variable"
```bash
# Check if variables are set
echo $SIMPRO_TEST_URL
echo $HUBSPOT_ACCESS_TOKEN

# If not, load them
source ../.env
```

### "Property not found in HubSpot"
```bash
# List all properties
./test_sync_locally.sh

# Create missing properties in HubSpot UI
# Settings → Objects → Deals → Properties
```

### Sync is running slow
```bash
# Use larger page size
ruby master_full_sync.rb --page-size=250 --verbose
```

### Need to stop sync
```bash
# Press Ctrl+C
# Note the last processed page
# Resume later with: --start-page=LAST_PAGE
```

---

## Success Checklist

Before considering sync complete:

- [ ] Test script ran successfully
- [ ] Small batch sync completed
- [ ] Random deals verified in HubSpot
- [ ] Line item totals match
- [ ] Associations present
- [ ] Full sync completed
- [ ] Summary shows acceptable error rate (<1%)
- [ ] Failed items documented
- [ ] Log file archived

---

## What to Do After Success

1. **Archive logs:**
   ```bash
   mkdir -p sync_logs
   mv sync_*.log sync_logs/
   ```

2. **Document results:**
   - Total quotes synced
   - Total failures
   - Any patterns in failures
   - Time taken

3. **Set up ongoing sync:**
   - Configure webhooks for real-time sync
   - Or schedule regular batch syncs

4. **Create reports in HubSpot:**
   - Deal totals by pipeline
   - Line item analysis
   - Cost center breakdowns

---

## Need Help?

1. **Check logs:** `sync_*.log`
2. **Read docs:** `docs/MASTER_DATA_SYNC_MAPPING.md`
3. **Re-run tests:** `./test_sync_locally.sh`
4. **Test single quote:** Modify test script to sync specific quote ID

---

**Ready to start? Run:** `./test_sync_locally.sh` 🚀

