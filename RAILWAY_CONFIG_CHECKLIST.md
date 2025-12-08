# Railway Configuration Checklist

## ✅ Complete Setup Guide for Railway Deployment

### 1. **Build Configuration** ✓

**Setting:** `Build` → `Builder`  
**Value:** `Dockerfile`

**Setting:** `Build` → `Dockerfile Path`  
**Value:** `Dockerfile`

**Status:** ✅ Configured in `railway.toml`

---

### 2. **Deploy Configuration** ✓

**Setting:** `Deploy` → `Start Command`  
**Value:** 
```bash
bundle exec ruby one-time-sync/master_full_sync_v2.rb --verbose
```

**Setting:** `Deploy` → `Restart Policy`  
**Value:** `Never` (one-time sync, should not restart)

**Status:** ✅ Configured in `railway.toml`

---

### 3. **Environment Variables** (Set in Railway Dashboard)

Go to: **Railway Dashboard** → **Your Service** → **Variables** tab

#### Required Variables:

| Variable Name | Example Value | Notes |
|--------------|---------------|-------|
| `SIMPRO_TEST_URL` | `https://solarhub.simprosuite.com/api/v1.0/companies/4` | Your SimPRO API base URL |
| `SIMPRO_TEST_KEY_ID` | `f821239d...` | Your SimPRO API key |
| `HUBSPOT_ACCESS_TOKEN` | `pat-ap1-a02aa83e...` | Your HubSpot access token |
| `RAILS_ENV` | `production` | Should be production |
| `SECRET_KEY_BASE` | `abcdefg...` | Any random string (for Rails) |

#### Optional Variables:

| Variable Name | Example Value | Notes |
|--------------|---------------|-------|
| `CSV_FILE` | `hubspot-crm-exports-all-deals-2025-11-28.csv` | Override default CSV file |
| `LIMIT` | `100` | Limit number of deals to sync (for testing) |
| `SKIP_LINE_ITEMS` | `false` | Set to `true` to skip line items |
| `SKIP_ASSOCIATIONS` | `false` | Set to `true` to skip associations |
| `RUBY_DEBUG_SKIP` | `1` | Disable debug gem (already set in Dockerfile) |

**Status:** ⚠️ **You must configure these in Railway Dashboard**

---

### 4. **CSV File** ✓

**File:** `hubspot-crm-exports-all-deals-2025-11-28.csv`  
**Location:** Included in repository  
**Size:** 791 KB (11,585 lines)

The Dockerfile copies this file into the container at:
```
/app/one-time-sync/hubspot-crm-exports-all-deals-2025-11-28.csv
```

**Status:** ✅ File exists and will be copied during build

---

### 5. **Region & Resources**

**Setting:** `Settings` → `Region`  
**Recommended:** `us-west-2` (or closest to your location)

**Status:** ✅ Set to `us-west-2` (visible in your screenshot)

---

### 6. **Deployment Trigger**

**Method:** Automatic on Git push  
**Repository:** `alexatafm/solar-hub-sync`  
**Branch:** `main`

**Status:** ✅ Connected to GitHub

---

## 🚀 How to Deploy

### Option A: Automatic Deployment (Recommended)
1. Push changes to GitHub `main` branch
2. Railway automatically detects changes
3. Builds Docker image using `Dockerfile`
4. Runs the sync with your environment variables

### Option B: Manual Deployment
1. Go to Railway Dashboard
2. Click **"Deploy"** button
3. Railway will rebuild and redeploy

---

## 🔍 Verify Configuration

### In Railway Dashboard:

#### ✓ Variables Tab
- [ ] `SIMPRO_TEST_URL` is set
- [ ] `SIMPRO_TEST_KEY_ID` is set
- [ ] `HUBSPOT_ACCESS_TOKEN` is set
- [ ] `RAILS_ENV` = `production`
- [ ] `SECRET_KEY_BASE` is set

#### ✓ Settings Tab → Deploy
- [ ] Start command: `bundle exec ruby one-time-sync/master_full_sync_v2.rb --verbose`
- [ ] Restart policy: `never`

#### ✓ Settings Tab → Build
- [ ] Builder: `Dockerfile`
- [ ] Dockerfile path: `Dockerfile`

---

## 📊 Expected Output

When the sync runs successfully, you should see:

```
[2025-12-08 XX:XX:XX] [INFO] ====================================================================================================
[2025-12-08 XX:XX:XX] [INFO] MASTER FULL DATA SYNC V2
[2025-12-08 XX:XX:XX] [INFO] ====================================================================================================
[2025-12-08 XX:XX:XX] [INFO] Started at: 2025-12-08 XX:XX:XX UTC
[2025-12-08 XX:XX:XX] [INFO] CSV File: hubspot-crm-exports-all-deals-2025-11-28.csv
[2025-12-08 XX:XX:XX] [INFO] ====================================================================================================
[2025-12-08 XX:XX:XX] [INFO] ✅ Loaded CSV successfully | total_deals=11063 | unique_quotes=11063
[2025-12-08 XX:XX:XX] [INFO] Starting sync: | total_available=11063 | range=0-11062 | to_sync=11063
...
[2025-12-08 XX:XX:XX] [PROGRESS] 1/11063 (0.0%) | Remaining: 11062 | ETA: X.Xh | quote_id=XXXXX
...
[2025-12-08 XX:XX:XX] [SUCCESS] ✅ Synced successfully | quote_id=XXXXX | deal_id=XXXXX | duration=XX.XXs
```

---

## 🐛 Troubleshooting

### Issue: Build Fails with "not found" error
**Solution:** Make sure the CSV file is committed to the repo:
```bash
git add hubspot-crm-exports-all-deals-2025-11-28.csv
git commit -m "Add CSV file"
git push origin main
```

### Issue: Sync fails with API errors
**Solution:** Check environment variables are correct:
- `SIMPRO_TEST_URL` should end with `/companies/4`
- `SIMPRO_TEST_KEY_ID` is your API key (not URL)
- `HUBSPOT_ACCESS_TOKEN` starts with `pat-ap1-`

### Issue: Sync runs but no data is updated
**Solution:** Check the logs for specific error messages. The structured logging will show exactly which deals failed and why.

---

## 📈 Performance Expectations

Based on local testing:

- **Speed:** ~187 deals/hour (~18.7s per deal)
- **Total Time for 11,063 deals:** ~59 hours
- **Line Items Created:** Average 18 per deal
- **Associations Created:** 1-2 per deal

**Note:** Railway's network is faster than local, so actual speed may be better.

---

## ✅ Final Checklist

Before deploying:

- [ ] All environment variables configured in Railway
- [ ] Start command updated to use `master_full_sync_v2.rb`
- [ ] CSV file committed to repository
- [ ] Latest code pushed to GitHub
- [ ] Railway deployment status shows "Completed"

**Once all items are checked, you're ready to deploy!** 🎉

