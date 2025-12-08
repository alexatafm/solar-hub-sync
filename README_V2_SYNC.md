# Master Full Sync V2 - Complete Re-Sync with Enhanced Logging

**Created:** December 8, 2025  
**Version:** 2.0.0  
**Purpose:** Comprehensive re-sync of all deals with cost-center discount fixes, site/contact associations, and enhanced observability

---

## 🎯 What's New in V2

### Core Improvements

1. **Cost-Center-Based Discount Calculation** (Fixed Dec 8, 2025)
   - Accurate proportional discount distribution per cost center
   - STCs/VEECs only applied to hot water and solar systems
   - Line item totals now match simPRO exactly

2. **Site & Contact Associations**
   - Automatically creates deal → site associations
   - Automatically creates deal → contact/company associations
   - Ensures proper relationship tracking in HubSpot

3. **Enhanced Structured Logging**
   - Console output with progress tracking
   - Detailed file logging for debugging
   - **CSV report for easy analysis and reporting**
   - Error categorization and grouping

4. **Better Error Handling**
   - Graceful handling of missing data
   - Network timeout recovery
   - Detailed error tracking with backtraces

---

## 📊 Logging Output

### Three Log Types

1. **Console Log (STDOUT)**
   - Real-time progress updates
   - High-level status messages
   - ETA calculations
   - Summary report

2. **Detailed File Log** (`sync_YYYYMMDD_HHMMSS.log`)
   - Complete sync history
   - Debug information
   - Error stack traces
   - API responses

3. **CSV Report** (`sync_YYYYMMDD_HHMMSS_report.csv`)
   - Structured data for analysis
   - Import into Excel/Google Sheets
   - Columns: Timestamp, Level, Event, Quote_ID, Deal_ID, Deal_Name, Duration_Sec, Line_Items, Associations, Status, Error_Class, Error_Message
   - Perfect for creating reports and charts

### Example CSV Output

```csv
Timestamp,Level,Event,Quote_ID,Deal_ID,Deal_Name,Duration_Sec,Line_Items,Associations,Status,Error_Class,Error_Message
2025-12-08T10:15:23Z,SUCCESS,✅ Synced successfully,50123,12345678,50123 - Smith Residence,4.23,15,2,success,,
2025-12-08T10:15:28Z,SKIP,Archived duplicate,50124,12345679,50124 - Jones Home,0.12,,,skipped_duplicate,,
2025-12-08T10:15:35Z,ERROR,Sync failed,50125,12345680,50125 - Brown Office,2.45,,,failed,HTTPError,Network timeout
```

---

## 🚀 Quick Start

### Prerequisites

```bash
# 1. Ensure environment variables are set
export SIMPRO_TEST_URL="https://solarhub.simprosuite.com/api/v1.0/companies/4"
export SIMPRO_TEST_KEY_ID="your_simpro_api_key"
export HUBSPOT_ACCESS_TOKEN="your_hubspot_token"

# 2. Ensure you have the CSV export file
# File: hubspot-crm-exports-all-deals-2025-11-28.csv
# Or specify custom file with --csv-file option
```

### Basic Usage

```bash
# Sync first 100 deals (test run)
ruby master_full_sync_v2.rb --limit=100 --verbose

# Sync specific range
ruby master_full_sync_v2.rb --start-index=0 --end-index=500 --verbose

# Sync all deals (production run)
ruby master_full_sync_v2.rb --verbose

# Dry run (preview without making changes)
ruby master_full_sync_v2.rb --limit=10 --dry-run --verbose
```

### Advanced Options

```bash
# Filter by pipeline
ruby master_full_sync_v2.rb --pipeline=default --verbose              # Residential only
ruby master_full_sync_v2.rb --pipeline=1012446696 --verbose           # Commercial only
ruby master_full_sync_v2.rb --pipeline=1011198445 --verbose           # Service only

# Skip line items (faster, deal properties only)
ruby master_full_sync_v2.rb --skip-line-items --verbose

# Skip associations (no site/contact linking)
ruby master_full_sync_v2.rb --skip-associations --verbose

# Custom CSV file
ruby master_full_sync_v2.rb --csv-file=my-deals-export.csv --verbose

# Handle duplicates differently
ruby master_full_sync_v2.rb --duplicates=all --verbose                # Sync all duplicates
ruby master_full_sync_v2.rb --duplicates=skip --verbose               # Skip all duplicates
ruby master_full_sync_v2.rb --duplicates=first --verbose              # Keep first (default)
```

---

## 📈 Expected Performance

### Sync Speed

- **With line items:** ~4-6 seconds per deal
- **Without line items:** ~2-3 seconds per deal
- **Typical throughput:** 600-900 deals/hour (with line items)
- **Total time for 1,000 deals:** ~1.5-2 hours

### Resource Usage

- **Network:** ~50-100 API calls per deal
- **Memory:** ~200-500 MB
- **CPU:** Minimal (I/O bound)

---

## 🎯 What Gets Synced

### Deal Properties (90+)

✅ Basic Information (ID, name, description, notes)  
✅ Status & Stage (status, pipeline, archive reason)  
✅ People (salesperson, project manager)  
✅ Customer & Site (IDs, names)  
✅ Dates (issued, approved, due, modified)  
✅ Financial - Basic (totals, tax)  
✅ Financial - Materials (costs, markup)  
✅ Financial - Resources (labor, equipment, commission)  
✅ Financial - Profit/Loss (gross, nett, margins)  
✅ Financial - Adjustments (discounts, memberships)  
✅ Financial - Certificates (STCs, VEECs, eligibility)  
✅ Financial - Calculated (net price, discount amount, final total)  
✅ Job Related (linked jobs, variations)  
✅ Forecast (year, month, percent)  
✅ Sync Metadata (timestamps, duration)

### Line Items (25+ properties each)

✅ Basic (name, SKU, quantity, type)  
✅ Pricing - Original (price, cost, markup, discount)  
✅ Pricing - Totals (ex-tax, inc-tax)  
✅ **Pricing - Discounted** (NEW: final prices after all adjustments)  
✅ Discount Handling (rebates, credits)  
✅ Cost Center Info (name, type, primary/optional)  
✅ Section Info (section ID, name)  
✅ Supplier  
✅ simPRO ID

### Associations

✅ Deal ↔ Site (using simpro_site_id)  
✅ Deal ↔ Contact (using simpro_customer_id)  
✅ Deal ↔ Company (using simpro_customer_id)  
✅ Deal ↔ Line Items (automatic during sync)

---

## 🔍 Monitoring & Observability

### During Sync

Watch console output for:
- Progress percentage
- ETA calculation
- Success/error counts
- Current deal being processed

Example output:
```
[2025-12-08 10:15:23] [PROGRESS] 50/1000 (5.0%) | Remaining: 950 | ETA: 1h 23m | quote_id=50123 | deal_id=12345678
[2025-12-08 10:15:27] [SUCCESS] ✅ Synced successfully | quote_id=50123 | deal_id=12345678 | duration=4.23 | line_items=15 | associations=2
```

### After Sync

1. **Check Summary Report**
   - Displayed at end of sync
   - Shows totals, success rate, performance metrics
   - Lists error categories and counts

2. **Analyze CSV Report**
   ```bash
   # Open in Excel/Google Sheets
   open sync_20251208_101523_report.csv
   
   # Or analyze with command line
   grep "ERROR" sync_20251208_101523_report.csv
   grep "SUCCESS" sync_20251208_101523_report.csv | wc -l
   ```

3. **Review Detailed Log**
   ```bash
   # Check for specific quote
   grep "quote_id=50123" sync_20251208_101523.log
   
   # View all errors
   grep "ERROR" sync_20251208_101523.log
   
   # View last 100 lines
   tail -100 sync_20251208_101523.log
   ```

---

## 🐛 Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "CSV file not found" | File path incorrect | Check file exists in one-time-sync folder or specify full path with --csv-file |
| "Missing environment variables" | ENV vars not set | Export SIMPRO_TEST_URL, SIMPRO_TEST_KEY_ID, HUBSPOT_ACCESS_TOKEN |
| "Deal not found" | Deal deleted from HubSpot | Normal - these are skipped and counted in summary |
| "Quote not found" | Quote deleted from simPRO | Normal - these are skipped and counted in summary |
| "Network timeout" | Slow connection or API issues | Script automatically retries and continues |
| "Rate limit" | Too many API calls | Script includes built-in delays (0.5s between deals) |

### Error Categories

The sync groups errors for easy analysis:

- **HTTPError:** Network or API errors
- **Timeout::Error:** Connection timeouts
- **StandardError:** Data processing errors
- **JSON::ParserError:** Malformed API responses

### Resume After Interruption

If sync is interrupted:

```bash
# Find last successfully synced index from log
grep "SUCCESS" sync_20251208_101523.log | tail -1

# Resume from next index
ruby master_full_sync_v2.rb --start-index=500 --verbose
```

---

## 📊 Reporting Examples

### Using CSV Report

**Calculate Success Rate:**
```bash
# Count successes
SUCCESS_COUNT=$(grep ",SUCCESS," sync_*_report.csv | wc -l)
# Count totals
TOTAL_COUNT=$(tail -n +2 sync_*_report.csv | wc -l)
# Calculate rate
echo "scale=2; $SUCCESS_COUNT * 100 / $TOTAL_COUNT" | bc
```

**Find Slowest Deals:**
```bash
# Sort by duration (column 7)
sort -t',' -k7 -rn sync_*_report.csv | head -10
```

**List All Errors:**
```bash
grep ",ERROR," sync_*_report.csv > errors_report.csv
```

**Group Errors by Type:**
```bash
awk -F',' '{print $11}' sync_*_report.csv | sort | uniq -c | sort -rn
```

---

## 🚀 Railway Deployment

### Preparation

1. **Export HubSpot Deals**
   - Go to HubSpot → Deals → Export
   - Include columns: Record ID, Deal Name, Simpro Quote Id, Amount, Pipeline
   - Save as `hubspot-crm-exports-all-deals-2025-12-08.csv`

2. **Update CSV in Repository**
   ```bash
   cp ~/Downloads/hubspot-crm-exports-all-deals-2025-12-08.csv one-time-sync/
   cd one-time-sync
   git add hubspot-crm-exports-all-deals-2025-12-08.csv
   git commit -m "Update deals export for re-sync"
   git push
   ```

3. **Configure Railway Service**
   - Set environment variables:
     - `SIMPRO_TEST_URL`
     - `SIMPRO_TEST_KEY_ID`
     - `HUBSPOT_ACCESS_TOKEN`
     - `RAILS_ENV=production`
   
   - Set start command:
     ```
     cd one-time-sync && ruby master_full_sync_v2.rb --csv-file=hubspot-crm-exports-all-deals-2025-12-08.csv --verbose
     ```

4. **Deploy & Monitor**
   ```bash
   # Watch logs in real-time
   railway logs --follow
   
   # After completion, download CSV report
   railway run cat sync_*_report.csv > local_report.csv
   ```

---

## 📋 Pre-Deployment Checklist

Before running production sync:

- [ ] Export fresh deals CSV from HubSpot
- [ ] Verify CSV contains all expected deals
- [ ] Update CSV filename in script or command line
- [ ] Test with --limit=10 --dry-run
- [ ] Test with --limit=100 on small batch
- [ ] Verify environment variables are set
- [ ] Verify API credentials are valid
- [ ] Schedule sync during off-peak hours
- [ ] Notify team of sync in progress
- [ ] Prepare to monitor logs

---

## 🎯 Success Criteria

After sync completes:

✅ **Success rate > 95%**  
✅ **No critical errors** (HTTPError, network issues OK)  
✅ **Line items created for all deals**  
✅ **Site associations created**  
✅ **Contact/company associations created**  
✅ **CSV report generated for review**  
✅ **Summary shows expected totals**

---

## 📞 Support

### If Sync Fails

1. Check error summary in console output
2. Review CSV report for specific failures
3. Check detailed log file for stack traces
4. Retry failed quotes individually with test script

### For Help

- Review this documentation
- Check related docs in `/docs` folder
- Examine log files for detailed errors
- Contact development team with:
  - Log files (both .log and _report.csv)
  - Error summary from console
  - Approximate time of failure

---

## 🔄 Comparison with V1

| Feature | V1 | V2 |
|---------|----|----|
| Cost-center discounts | ❌ Proportional only | ✅ Cost-center-specific |
| Site associations | ❌ No | ✅ Yes |
| Contact associations | ❌ No | ✅ Yes |
| CSV reporting | ❌ No | ✅ Yes |
| Structured logging | ⚠️ Basic | ✅ Enhanced |
| Error categorization | ❌ No | ✅ Yes |
| Progress tracking | ⚠️ Basic | ✅ ETA calculation |
| Resume capability | ✅ Yes | ✅ Yes (improved) |

---

**Prepared By:** Development Team  
**Last Updated:** December 8, 2025  
**Version:** 2.0.0  
**Status:** Production Ready

