# Pre-Deployment Summary: Job Sync Gross Margin Fix

## 🎯 **Problem Identified**

The deployed Rails webhook receiver was overwriting correct gross margin values with incorrect ones because it was using the **dollar amount** (`GrossMargin.Actual` = $100) instead of the **percentage** (`GrossMargin.Estimate` = 29.42%).

## ✅ **Changes Made**

### 1. **Fixed Gross Margin Logic** (Both Apps)

**Main Rails App** (`app/models/simpro/job.rb`):
- **OLD**: `data[:actual_gross_margin] = job_response["Totals"]["GrossMargin"]["Actual"]` → Stored $100 as 100%
- **NEW**: Uses `GrossMargin.Estimate` or `GrossMargin.Percentage`, converts to decimal (29.42% = 0.2942)

**One-Time Sync** (`one-time-sync/jobs-sync/sync_jobs.rb`):
- **SAME FIX**: Identical gross margin percentage logic

### 2. **Fixed Invoice Percentage Calculation** (Both Apps)

**OLD**: Stored as percentage (6.51)
**NEW**: Stored as decimal (0.0651) for proper HubSpot display

### 3. **Added Feature Flag to Disable Job Webhooks**

**File**: `app/controllers/simpro_controller.rb`

```ruby
if ENV['DISABLE_JOB_WEBHOOK_SYNC'] == 'true'
  Rails.logger.info "⏸️  Job webhook sync disabled"
  head :ok
  return
end
```

**Usage**:
- Set `DISABLE_JOB_WEBHOOK_SYNC=true` on Heroku during historic sync
- Set `DISABLE_JOB_WEBHOOK_SYNC=false` to re-enable after sync completes

### 4. **Added Association Logic to One-Time Sync**

The one-time sync now automatically associates jobs with:

**✅ Contacts** (Customers):
- Searches by email first
- Falls back to Simpro Customer ID
- Uses association type 60 (Job → Contact)

**✅ Sites**:
- Searches by Simpro Site ID
- Uses association type 61 (Job → Site)

**Methods Added**:
- `associate_job_with_related_records()` - Main orchestrator
- `associate_contact()` - Links job to contact
- `associate_site()` - Links job to site
- `search_contact_by_email()` - Finds HubSpot contact
- `search_contact_by_simpro_id()` - Finds by Simpro ID
- `search_site_by_simpro_id()` - Finds HubSpot site

## 📊 **Field Mapping Comparison**

### **Both Apps Extract Identical Fields:**

| Category | Fields | Source | Destination |
|----------|--------|--------|-------------|
| **Basic Info** | Job Name, Stage, Status, ID | Simpro Job | HubSpot Job |
| **Financial** | Total Ex/Inc Tax, Invoiced Value, **Gross Margin %**, **Invoice %** | `Total.*`, `Totals.*` | HubSpot properties |
| **Dates** | Date Issued, Completed, Modified | Simpro dates | Midnight UTC timestamps |
| **People** | Salesperson, Project Manager | `Salesperson.Name`, `ProjectManager.Name` | HubSpot text fields |
| **Custom Fields** | Region, Financing, SmartR Quote Link, Installation Date | CustomFields by ID | HubSpot custom properties |
| **Pipeline** | Status → Pipeline Stage | `Status.Name` | `hs_pipeline_stage` |

### **Key Differences:**

| Feature | Main App (Webhooks) | One-Time Sync |
|---------|---------------------|---------------|
| **Trigger** | Simpro webhook | Manual/scheduled execution |
| **Scope** | Single job update | Batch processing (all historic jobs) |
| **Associations** | Only for warranty jobs | **ALL jobs** (contacts + sites) |
| **Rate Limiting** | None (single requests) | Built-in (2/sec Simpro, 10/sec HubSpot) |
| **Retries** | None | Automatic with exponential backoff |
| **Reporting** | Rails logs | CSV report + detailed logs |

## 🚀 **Deployment Steps**

### Step 1: Pause Job Webhook Processing
```bash
# On Heroku production app
heroku config:set DISABLE_JOB_WEBHOOK_SYNC=true -a your-app-name
```

### Step 2: Deploy Main App Fixes
```bash
cd /Users/alexmoore/Development/Solarhub-simpro-hubspot/solar-hub-simpro

# Stage changes
git add app/models/simpro/job.rb
git add app/controllers/simpro_controller.rb

# Commit
git commit -m "Fix: Correct gross margin percentage calculation and add webhook disable flag

- Changed GrossMargin.Actual ($) to GrossMargin.Estimate (%)
- Store percentages as decimals for HubSpot (0.2942 not 29.42)
- Add DISABLE_JOB_WEBHOOK_SYNC environment variable
- Fix invoice percentage calculation"

# Deploy
git push heroku main
# OR
git push origin main
```

### Step 3: Deploy One-Time Sync to Railway
```bash
cd one-time-sync/jobs-sync

# Build Docker image
docker-compose build

# Test locally first
MAX_JOBS=10 make test-50

# Deploy to Railway (via GitHub)
git add .
git commit -m "Add association logic for contacts and sites"
git push origin main
```

### Step 4: Run Historic Sync on Railway
```
# Via Railway dashboard or CLI
railway run ruby sync_jobs.rb
```

### Step 5: Re-enable Job Webhooks
```bash
# After historic sync completes
heroku config:set DISABLE_JOB_WEBHOOK_SYNC=false -a your-app-name
```

## ⚠️ **Critical Verifications Before Deployment**

- [ ] **Webhook flag tested**: Confirm webhooks are paused
- [ ] **Local test successful**: 50+ jobs with associations
- [ ] **Field values correct**: Gross margin showing as 29.42%, not 10000%
- [ ] **Associations working**: Jobs linked to contacts and sites
- [ ] **No data loss**: All 29 fields being synced correctly

## 📝 **Files Modified**

### Main App (Rails)
1. `app/models/simpro/job.rb` - Fixed gross margin extraction
2. `app/controllers/simpro_controller.rb` - Added feature flag

### One-Time Sync
1. `sync_jobs.rb` - Fixed gross margin + added associations
2. `Dockerfile` - Added debug_sync.rb
3. `docker-compose.yml` - Dynamic MAX_JOBS

## 🔄 **Post-Deployment Monitoring**

1. **Monitor Heroku logs** for paused webhook confirmations
2. **Monitor Railway logs** for sync progress
3. **Verify random sample** of 10-20 jobs in HubSpot
4. **Check associations** are present (contacts, sites)
5. **Verify gross margin** displays correctly (< 100%)

## 📊 **Expected Results**

After deployment:
- ✅ All historic jobs have correct gross margin percentages
- ✅ Jobs are associated with contacts (customers)
- ✅ Jobs are associated with sites
- ✅ No webhook interference during sync
- ✅ All 29+ fields mapped correctly
- ✅ Pipeline stages set based on Simpro status

---

**Ready for Deployment**: Pending final user review and approval

