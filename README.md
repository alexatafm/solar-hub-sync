# One-Time Sync Scripts - simPRO ↔ HubSpot

**Last Updated:** December 8, 2025  
**Current Version:** 2.0.0  
**Status:** Production Ready

---

## 🚀 **RECOMMENDED: Use Master Sync V2**

### ⭐ **V2 includes critical fixes - use for all new syncs:**

- ✅ **Cost-center-based discount calculation** (matches simPRO exactly)
- ✅ **Site & contact associations** (proper CRM relationships)
- ✅ **Enhanced structured logging** (CSV reports for easy analysis)
- ✅ **Better error handling** (categorized, recoverable)

---

## 🎯 Quick Start

### 1. Test First (Required)

```bash
# Run automated test suite
./test_sync_v2.sh

# This checks:
# - Environment variables
# - API connectivity  
# - CSV file exists
# - Runs dry-run and test sync
```

### 2. Production Sync

```bash
# Full sync (all deals)
ruby master_full_sync_v2.rb --verbose

# Test with small batch first (recommended)
ruby master_full_sync_v2.rb --limit=100 --verbose

# By pipeline
ruby master_full_sync_v2.rb --pipeline=default --verbose  # Residential only
```

---

## 📚 Documentation

### **Start Here**

1. **[README_V2_SYNC.md](README_V2_SYNC.md)** ⭐ - Complete V2 usage guide
2. **[test_sync_v2.sh](test_sync_v2.sh)** - Automated test script

### Deployment

3. **[RAILWAY_DEPLOYMENT_V2.md](RAILWAY_DEPLOYMENT_V2.md)** - Deploy to Railway
4. **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** - Pre-deployment checklist

### Reference

5. **[CHANGELOG_V2.md](CHANGELOG_V2.md)** - What changed and why
6. **[README_MASTER_SYNC.md](README_MASTER_SYNC.md)** - Legacy V1 docs

---

## 📦 Available Scripts

### Master Sync V2 (Recommended)

**File:** `master_full_sync_v2.rb`  
**Version:** 2.0.0  
**Date:** December 8, 2025

**What it syncs:**
- All deal properties (90+ fields)
- Line items with correct discount calculations
- Site associations
- Contact/company associations

**Usage:**
```bash
# Basic
ruby master_full_sync_v2.rb --verbose

# With options
ruby master_full_sync_v2.rb --limit=N --pipeline=PIPE --verbose

# Available options:
#   --csv-file=FILE         Custom CSV file
#   --start-index=N         Start from deal N
#   --end-index=N           End at deal N
#   --limit=N               Sync only N deals
#   --pipeline=PIPE         Filter: default, 1012446696, 1011198445
#   --skip-line-items       Faster, properties only
#   --skip-associations     No site/contact linking
#   --dry-run               Preview without changes
#   --verbose               Detailed logging
```

### Master Sync V1 (Legacy - Deprecated)

**File:** `master_full_sync.rb`  
**Status:** ⚠️ **DO NOT USE** - has incorrect discount calculations  
**Use V2 instead**

---

## 🎨 What Gets Synced

### Deal Properties (90+ fields)

✅ Basic Info (ID, name, description, notes)  
✅ Status & Stage (status, pipeline, archive reason)  
✅ People (salesperson, project manager)  
✅ Dates (issued, approved, due, modified)  
✅ Financial - Basic (totals, tax)  
✅ Financial - Materials (costs, markup)  
✅ Financial - Resources (labor, equipment)  
✅ Financial - Profit/Loss (gross, nett, margins)  
✅ Financial - Discounts (quote-level adjustments)  
✅ Financial - Certificates (STCs, VEECs)  
✅ Financial - Calculated (net price, final total)  
✅ Job Related (linked jobs, variations)

### Line Items (25+ properties each)

✅ Basic (name, SKU, quantity, type)  
✅ Pricing - Original (price, cost, markup)  
✅ Pricing - Totals (ex-tax, inc-tax)  
✅ **Pricing - Discounted** (NEW in V2: final prices after all adjustments)  
✅ Cost Center Info (name, type, primary/optional)  
✅ Section Info (section ID, name)  
✅ Supplier, simPRO ID

### Associations (NEW in V2)

✅ Deal ↔ Site  
✅ Deal ↔ Contact  
✅ Deal ↔ Company  
✅ Deal ↔ Line Items

---

## 📊 Logging & Reports

### Three Types of Logs

1. **Console Output** (real-time)
   - Progress tracking
   - Success/error counts
   - ETA calculations

2. **Detailed Log File** (`sync_YYYYMMDD_HHMMSS.log`)
   - Complete sync history
   - Debug information
   - Error stack traces

3. **CSV Report** (`sync_YYYYMMDD_HHMMSS_report.csv`) ⭐
   - Structured data
   - Import to Excel/Sheets
   - Easy error analysis
   - Performance metrics

**CSV Columns:**
```
Timestamp, Level, Event, Quote_ID, Deal_ID, Deal_Name, 
Duration_Sec, Line_Items, Associations, Status, 
Error_Class, Error_Message
```

---

## 📈 Performance

### Expected Speed

- **With line items:** 4-6 seconds per deal
- **Without line items:** 2-3 seconds per deal
- **Throughput:** 600-900 deals/hour

### For 1,800 Deals

- **Time:** 2-3 hours
- **Line Items:** ~25,000
- **Associations:** ~3,600
- **Success Rate:** 95-98%

---

## 🔧 Prerequisites

### Environment Variables

```bash
export SIMPRO_TEST_URL="https://solarhub.simprosuite.com/api/v1.0/companies/4"
export SIMPRO_TEST_KEY_ID="your_simpro_api_key"
export HUBSPOT_ACCESS_TOKEN="your_hubspot_token"
export RAILS_ENV="production"
```

### CSV Export

1. Go to HubSpot → Deals → Export
2. Include: Record ID, Deal Name, Simpro Quote Id, Amount, Pipeline
3. Save as: `hubspot-crm-exports-all-deals-YYYY-MM-DD.csv`
4. Place in this directory

---

## 🚨 Important Notes

### Why Re-Sync is Needed

V1 had **incorrect discount calculations**. Line item prices didn't match simPRO invoices.

**V2 fixes:**
- Cost-center-specific discount ratios
- STCs only applied to hot water/solar
- Prices match simPRO exactly

**Who needs re-sync:** All deals with:
- Discounts
- STCs or VEECs
- Multiple cost centers

### Safe to Re-Run

✅ No deletions occur  
✅ Updates existing data  
✅ Idempotent (safe to run multiple times)  
✅ Can resume after interruption

---

## 🧪 Testing

### Before Production

```bash
# 1. Run automated tests
./test_sync_v2.sh

# 2. Test with 5 deals
ruby master_full_sync_v2.rb --limit=5 --verbose

# 3. Verify in HubSpot
# Check line item prices match simPRO

# 4. Test with 100 deals
ruby master_full_sync_v2.rb --limit=100 --verbose

# 5. Review CSV report
open sync_*_report.csv
```

---

## 🐛 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "CSV file not found" | Ensure file is in this directory, check filename |
| "Missing environment variables" | Export SIMPRO_TEST_URL, SIMPRO_TEST_KEY_ID, HUBSPOT_ACCESS_TOKEN |
| "Deal not found" | Normal - these are skipped |
| "Quote not found" | Normal - these are skipped |
| "Network timeout" | Script continues automatically |

### Resume After Interruption

```bash
# Find last successful deal
grep "SUCCESS" sync_*.log | tail -1

# Resume from next index
ruby master_full_sync_v2.rb --start-index=500 --verbose
```

---

## 📋 Deployment Checklist

### Before Running

- [ ] Fresh CSV exported from HubSpot
- [ ] Environment variables set
- [ ] Test run completed (`./test_sync_v2.sh`)
- [ ] Small batch tested (--limit=100)
- [ ] Team notified
- [ ] Scheduled for off-peak hours

### During Sync

- [ ] Logs being monitored
- [ ] Progress increasing
- [ ] Success rate acceptable
- [ ] Errors minimal (<5%)

### After Sync

- [ ] Summary reviewed
- [ ] CSV report analyzed
- [ ] Spot checks completed
- [ ] Errors documented
- [ ] Team notified

---

## 🚀 Railway Deployment

For production runs, deploy to Railway for:
- Better network performance
- Persistent logs
- No local computer needed

**See:** [RAILWAY_DEPLOYMENT_V2.md](RAILWAY_DEPLOYMENT_V2.md)

**Quick Deploy:**
```bash
# 1. Push to GitHub
git add . && git commit -m "Update sync" && git push

# 2. Deploy to Railway
railway up

# 3. Monitor
railway logs --follow
```

---

## 📊 Example Reports

### Using CSV Report

**Success Rate:**
```bash
grep ",SUCCESS," sync_*_report.csv | wc -l
```

**Error Analysis:**
```bash
awk -F',' '{print $11}' sync_*_report.csv | sort | uniq -c
```

**Slowest Deals:**
```bash
sort -t',' -k7 -rn sync_*_report.csv | head -10
```

---

## 📞 Support

### Documentation
1. **README_V2_SYNC.md** - Complete usage guide
2. **RAILWAY_DEPLOYMENT_V2.md** - Deployment guide
3. **CHANGELOG_V2.md** - What's new and why

### For Issues
1. Check log files (especially CSV report)
2. Review error messages
3. Check documentation
4. Contact development team with:
   - Log files (.log and _report.csv)
   - Error summary
   - Time of failure

---

## 🔄 Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0.0 | Dec 8, 2025 | Cost-center discounts, associations, CSV logging |
| 1.1.0 | Nov 27, 2025 | CSV-based sync, duplicate handling |
| 1.0.0 | Nov 21, 2025 | Initial release |

---

## 🎯 Success Criteria

After sync completes:

✅ Success rate > 95%  
✅ Line items created for all deals  
✅ Prices match simPRO (spot check 20 deals)  
✅ Site associations created  
✅ Contact associations created  
✅ CSV report generated  
✅ No critical errors

---

**Prepared By:** Development Team  
**Last Updated:** December 8, 2025  
**Version:** 2.0.0  
**Status:** Production Ready ✨
