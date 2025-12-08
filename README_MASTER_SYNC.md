# Master Full Data Sync

## Overview

This directory contains the comprehensive one-time sync script that synchronizes **ALL** data from simPRO to HubSpot:

- ✅ **Contacts** (Individual Customers)
- ✅ **Companies** (Company Customers)
- ✅ **Sites** (Locations)
- ✅ **Deals** (Quotes)
- ✅ **Line Items** (Quote Items)

## Files

| File | Purpose |
|------|---------|
| `master_full_sync.rb` | Main sync script with logging and error handling |
| `test_sync_locally.sh` | Local testing script (curl-based validation) |
| `Dockerfile.master_sync` | Docker container for deployment |
| `README_MASTER_SYNC.md` | This file |

## Prerequisites

### Required Environment Variables

```bash
SIMPRO_TEST_URL=https://newdata.simpro.com.au/api/v1.0/companies/0
SIMPRO_TEST_KEY_ID=your_simpro_api_key
HUBSPOT_ACCESS_TOKEN=your_hubspot_token
```

### Required HubSpot Properties

All properties listed in `docs/MASTER_DATA_SYNC_MAPPING.md` must exist in HubSpot before running the sync.

## Local Testing

### Step 1: Test API Connectivity

```bash
cd one-time-sync
chmod +x test_sync_locally.sh
./test_sync_locally.sh
```

This will:
- ✅ Validate environment variables
- ✅ Test simPRO API connection
- ✅ Test HubSpot API connection
- ✅ Verify required properties exist
- ✅ Optionally sync a single test quote

### Step 2: Dry Run

Test without making changes:

```bash
ruby master_full_sync.rb --dry-run --verbose
```

### Step 3: Sync Small Batch

Sync just 5 pages (250 quotes):

```bash
ruby master_full_sync.rb --start-page=1 --end-page=5 --verbose
```

### Step 4: Monitor Results

Check:
- Console output for errors
- Log file: `sync_YYYYMMDD_HHMMSS.log`
- HubSpot for synced data

## Production Sync

### Full Sync (All Quotes)

```bash
ruby master_full_sync.rb --verbose
```

### Resume from Page N

If sync was interrupted:

```bash
ruby master_full_sync.rb --start-page=42 --verbose
```

### Sync Specific Range

```bash
ruby master_full_sync.rb --start-page=1 --end-page=100 --verbose
```

## Docker Deployment

### Build Container

```bash
cd /Users/alexmoore/Development/Solarhub-simpro-hubspot/solar-hub-simpro
docker build -f one-time-sync/Dockerfile.master_sync -t solar-hub-master-sync .
```

### Run Locally (Docker)

```bash
docker run --env-file .env solar-hub-master-sync --verbose
```

### Deploy to Railway

1. **Create new Railway service:**
   ```bash
   railway up
   ```

2. **Set environment variables in Railway dashboard:**
   - `SIMPRO_TEST_URL`
   - `SIMPRO_TEST_KEY_ID`
   - `HUBSPOT_ACCESS_TOKEN`

3. **Deploy:**
   ```bash
   railway deploy
   ```

4. **Monitor logs:**
   ```bash
   railway logs
   ```

## Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--start-page=N` | Start from page N | `--start-page=10` |
| `--end-page=N` | End at page N | `--end-page=50` |
| `--page-size=N` | Items per page (max 250) | `--page-size=100` |
| `--dry-run` | Preview without syncing | `--dry-run` |
| `--verbose` | Detailed logging | `--verbose` |
| `--quotes-only` | Skip customers/sites | `--quotes-only` |
| `-h, --help` | Show help | `--help` |

## Performance

### Expected Timing

| Operation | Time |
|-----------|------|
| Single Quote (with line items) | ~3-5 seconds |
| Page of 50 Quotes | ~3-5 minutes |
| Full Sync (1000 quotes) | ~1-2 hours |

### Optimization Tips

1. **Use larger page size** (up to 250): `--page-size=250`
2. **Run during off-peak hours** to avoid rate limits
3. **Use Railway** for better network latency
4. **Monitor logs** for any failing quotes

## Error Handling

### Automatic Retry

The script automatically handles:
- ✅ Rate limit delays
- ✅ Temporary API errors
- ✅ Network timeouts

### Manual Intervention Required

If sync fails completely:
1. Check the log file for error details
2. Note the last successfully synced page
3. Resume from next page: `--start-page=N`

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `401 Unauthorized` | Invalid API token | Check environment variables |
| `403 Forbidden` | Missing permissions | Verify HubSpot token scopes |
| `404 Not Found` | Quote/customer not found | Skip and continue |
| `429 Too Many Requests` | Rate limit exceeded | Reduce page size or add delays |
| `500 Server Error` | API outage | Wait and retry |

## Validation

### After Sync Completion

1. **Check summary output:**
   ```
   Customers: ✅ 500 synced, ❌ 2 failed
   Deals: ✅ 1000 synced, ❌ 5 failed
   Line Items: ✅ 15000 synced, ❌ 10 failed
   ```

2. **Verify in HubSpot:**
   - Check total deal count
   - Spot-check financial totals
   - Verify line item totals match
   - Check associations (contacts, sites)

3. **Run verification queries:**
   ```bash
   # Check for deals with discounted price sums
   ruby verify_sync_results.rb
   ```

## Logging

### Log Levels

- **INFO:** Successful operations
- **WARN:** Non-critical issues
- **ERROR:** Failed operations
- **DEBUG:** Detailed diagnostic info (--verbose only)

### Log Files

Format: `sync_YYYYMMDD_HHMMSS.log`

Example:
```
[2025-11-25 14:30:15] [INFO] Processing Quote 50123 - Test Quote
[2025-11-25 14:30:17] [INFO] ✅ Quote synced successfully
[2025-11-25 14:30:17] [INFO] ✅ 15 line items created
```

## Troubleshooting

### Sync is Slow

1. Increase page size: `--page-size=250`
2. Check network latency
3. Verify no rate limiting is occurring
4. Run on Railway for better performance

### Some Quotes Fail

1. Check log file for specific errors
2. Verify quote exists in simPRO
3. Check if customer/site data is valid
4. Try syncing failed quotes individually

### Line Items Not Created

1. Verify line item properties exist in HubSpot
2. Check if `display=all` parameter is working
3. Verify labour rates cache is loading
4. Check for cost center data issues

### Associations Missing

1. Verify customer was synced first
2. Check site was synced
3. Verify association type IDs are correct
4. Check HubSpot API response for errors

## Best Practices

### Before Running

- [ ] Test with `--dry-run` first
- [ ] Verify all HubSpot properties exist
- [ ] Test with small batch (5-10 pages)
- [ ] Check API credentials are valid
- [ ] Ensure no other syncs are running

### During Sync

- [ ] Monitor logs in real-time
- [ ] Watch for error patterns
- [ ] Check HubSpot for data appearing
- [ ] Monitor API rate limits
- [ ] Keep terminal/Railway session active

### After Sync

- [ ] Review summary statistics
- [ ] Check log file for errors
- [ ] Verify random sample in HubSpot
- [ ] Run validation queries
- [ ] Archive log file

## Support

### Getting Help

1. **Check logs:** Review `sync_*.log` file
2. **Read mapping docs:** `docs/MASTER_DATA_SYNC_MAPPING.md`
3. **Test locally:** Run `./test_sync_locally.sh`
4. **Check HubSpot:** Verify properties and data

### Reporting Issues

Include:
- Command used
- Error message from log
- Quote ID that failed (if applicable)
- HubSpot response (if available)
- Environment (local/Railway)

## Related Documentation

- **Mapping Reference:** `../docs/MASTER_DATA_SYNC_MAPPING.md`
- **Line Item Fix:** `../docs/DISCOUNTED_PRICE_CALCULATION_FIX.md`
- **Property Analysis:** `../docs/PROPERTY_REDUNDANCY_ANALYSIS.md`
- **Certificate Fields:** `../docs/NEW_CERTIFICATE_FIELDS.md`

---

**Last Updated:** November 25, 2025  
**Version:** 1.0.0

