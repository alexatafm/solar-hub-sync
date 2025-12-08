# 🏠 Residential Pipeline Sync Test Guide

**Date:** November 25, 2025  
**Purpose:** Test sync with 10 residential deals before full sync  
**Target:** Deals in "Residential Sales" (default) pipeline only

---

## 📋 Pre-Flight Checklist

Before testing, ensure:

- [ ] All environment variables are set (`./test_sync_locally.sh`)
- [ ] New HubSpot properties exist (90+ fields created)
- [ ] API connectivity working (simPRO + HubSpot)
- [ ] You have 15-20 minutes available
- [ ] HubSpot is open in a browser for verification

---

## 🎯 Test Objectives

This test will:

1. ✅ Sync exactly 10 residential pipeline deals
2. ✅ Update all 90+ new properties
3. ✅ Re-create line items with `discounted_price_inc_tax`
4. ✅ Fix Site associations
5. ✅ Verify Contact associations
6. ✅ Validate calculations match simPRO

**What We're Checking:**
- New properties populate correctly
- Line item calculations are accurate
- Site associations are created
- No deals are duplicated
- Existing data is preserved

---

## 🚀 OPTION 1: Dedicated Test Script (Recommended)

### Step 1: Run Pre-Flight Check

```bash
cd /Users/alexmoore/Development/Solarhub-simpro-hubspot/solar-hub-simpro/one-time-sync
./test_sync_locally.sh
```

**Expected Output:**
```
✅ All required environment variables are set
✅ simPRO API is accessible
✅ HubSpot API is accessible
✅ HubSpot properties verified
```

---

### Step 2: Run Test Sync

```bash
ruby test_residential_sync.rb
```

**What it does:**
- Searches through simPRO quotes
- Finds first 10 deals that are in Residential pipeline
- Syncs each one
- Shows detailed output for each deal

**Expected Output:**
```
🏠 RESIDENTIAL PIPELINE TEST SYNC
================================================================================
Configuration:
  Pipeline: Residential Sales (default)
  Test Size: 10 deals
  Line Items: Will be recreated with new calculations
================================================================================

🔍 Searching for residential pipeline deals...

📄 Checking page 1 (50 quotes)...

--------------------------------------------------------------------------------
✅ RESIDENTIAL DEAL FOUND: 55079 - 32 Dumas Street Mckellar
--------------------------------------------------------------------------------
  🔄 Syncing to HubSpot...
  ✅ Sync complete! (1/10)

  📊 Quote Details:
    Total (Inc Tax): $25000.00
    STCs: $684.00
    VEECs: $0.00
    Final Total: $24316.00

[... continues for 10 deals ...]

================================================================================
📊 TEST SYNC SUMMARY
================================================================================
  Time Elapsed: 45.2 seconds

  Quotes Checked: 87
  Residential Deals Found: 10
  Non-Residential Skipped: 15

  ✅ Successfully Synced: 10
  ❌ Failed: 0

================================================================================

🎉 SUCCESS! 10 residential deals updated.
```

**Estimated Time:** 1-2 minutes

---

### Step 3: Verify in HubSpot

The script will provide specific verification steps:

```bash
📋 NEXT STEPS - VERIFY IN HUBSPOT:

1. Go to HubSpot Deals
2. Filter by: Pipeline = 'Residential Sales'
3. Sort by: 'Last Modified Date' (newest first)
4. Open the top 10 deals
```

---

## 🚀 OPTION 2: Master Sync with Filters

Alternatively, use the master sync script with filters:

```bash
# Sync first 10 quotes that match residential pipeline
ruby master_full_sync.rb \
  --start-page=1 \
  --end-page=1 \
  --pipeline=default \
  --verbose
```

**Options Explained:**
- `--start-page=1` - Start from first page
- `--end-page=1` - Stop after first page (50 quotes)
- `--pipeline=default` - Only sync residential pipeline
- `--verbose` - Show detailed logging

**Note:** This will check up to 50 quotes but only sync those in residential pipeline.

---

## ✅ Verification Steps

After the test sync completes, verify the results in HubSpot:

### 1. Find the Synced Deals

**In HubSpot:**
1. Navigate to Deals
2. Add filter: `Pipeline = Residential Sales`
3. Sort by: `Last Modified Date` (newest first)
4. The top 10 deals should be the ones just synced

---

### 2. Check New Properties

Open one of the synced deals and verify these properties **NOW have values**:

#### Financial Properties (Should be populated):
- ✅ **simPRO Net Price (Inc Tax)** - Should show net price before discounts
- ✅ **Simpro Discount Amount (Inc Tax)** - Should show total discount
- ✅ **simPRO STCs** - Should show STC value (e.g., $684)
- ✅ **simPRO VEECs** - Should show VEEC value
- ✅ **simPRO Total Inc Tax** - Should show final total after STCs

#### Materials & Resources (Should be populated):
- ✅ **simPRO Materials Cost (Estimate)**
- ✅ **simPRO Materials Markup (Estimate)**
- ✅ **simPRO Resources Cost Total**
- ✅ **simPRO Resources Cost Labor**
- ✅ **simPRO Labor Hours (Estimate)**

#### Other Properties (Should be populated):
- ✅ **simPRO Project Manager** - Name of project manager
- ✅ **simPRO Date Modified** - Last modified date
- ✅ **simPRO Stage** - Quote stage (Lead, Quote, Won, Lost)
- ✅ **simPRO Status Color** - Status color code

---

### 3. Check Line Items

Click the **Line Items** tab and verify:

#### New Field Present:
- ✅ **Discounted Price (Inc Tax)** column should be visible
- ✅ All line items should have this field populated

#### Calculation Accuracy:
Open a specific line item and verify:
- `Discounted Price (Inc Tax)` ≠ `Price` (should be different)
- `Discounted Price (Inc Tax)` should be lower than `Price` (if discounts applied)

#### Cost Center Accuracy:
For Quote #50123 (if in test set):
- Air conditioning items: Sum of discounted prices should be close to $14,450
- Hot water items: Sum of discounted prices should be close to $7,850
- **Total across all line items:** Should equal **simPRO Total Inc Tax - STCs - VEECs**

---

### 4. Check Associations

Click the **Associations** tab and verify:

#### Should be present:
- ✅ **Contact** - Customer contact should be associated
- ✅ **Site** - Site should be associated (NEW!)
- ✅ **Line Items** - All line items should be listed

#### Previously Missing:
Before this sync, 99.9% of deals were missing Site associations. After sync, they should all be there!

---

### 5. Check Deal Properties (Preserved)

Verify these were **NOT** changed:

- ✅ **Pipeline** - Should still be "Residential Sales"
- ✅ **Deal Stage** - Should be preserved (not reset)
- ✅ **Deal Owner** - Should not change
- ✅ **Timeline/Notes** - Should still be present

---

## 🎯 Success Criteria

The test is successful if:

| Check | Expected Result | Status |
|-------|----------------|--------|
| New properties populated | All 90+ fields have values | ⬜ |
| Line items have `discounted_price_inc_tax` | All line items show this field | ⬜ |
| Site associations present | All 10 deals have sites associated | ⬜ |
| Contact associations present | All 10 deals have contacts | ⬜ |
| Financial totals match | Deal totals = simPRO totals | ⬜ |
| Line item sums match | Sum of line items = deal final total | ⬜ |
| No duplicates created | No duplicate deals found | ⬜ |
| Existing data preserved | Pipeline, stage, owner unchanged | ⬜ |

**If ALL checks pass:** ✅ Proceed to full sync

**If ANY checks fail:** ❌ Review errors, fix issues, re-test

---

## 📊 Sample Verification Queries

### Query 1: Check New Property Population

In HubSpot, create a report or list view with these columns:
- Deal Name
- Simpro Quote Id
- simPRO Net Price (Inc Tax)
- Simpro Discount Amount (Inc Tax)
- simPRO STCs
- simPRO Total Inc Tax

**Expected:** All 10 deals should show values in all columns.

---

### Query 2: Check Line Item Discounts

For one deal, export line items to CSV with columns:
- Name
- Price
- Discounted Price (Inc Tax)
- Cost Center

**Expected:** 
- `Discounted Price (Inc Tax)` populated for all items
- Sum of `Discounted Price (Inc Tax)` = Deal's "simPRO Total Inc Tax" - STCs

---

### Query 3: Check Site Associations

Filter deals by:
- Pipeline = Residential Sales
- Last Modified = Last hour
- Has Site Association = True

**Expected:** All 10 test deals should appear.

---

## 🐛 Troubleshooting

### Issue 1: No Deals Found

**Symptom:** Script says "No residential deals found"

**Causes:**
- First page of simPRO quotes may not have residential deals
- Deals may not exist in HubSpot yet
- Pipeline filter not working

**Solution:**
```bash
# Remove pipeline filter to see all deals
ruby master_full_sync.rb --start-page=1 --end-page=1 --verbose
```

---

### Issue 2: New Properties Not Populated

**Symptom:** Deal updated but new fields still show `--`

**Causes:**
- Properties not created in HubSpot
- API response doesn't include these fields
- Field mapping incorrect

**Solution:**
1. Check properties exist in HubSpot: Settings → Properties → Deals
2. Check property internal names match code
3. Review log file for API errors

---

### Issue 3: Line Items Not Updated

**Symptom:** Line items still show old values

**Causes:**
- Line item deletion failed
- Line item creation failed
- Associations not rebuilt

**Solution:**
1. Check log file for line item errors
2. Manually delete line items in HubSpot
3. Re-sync the deal

---

### Issue 4: Site Not Associated

**Symptom:** Site association missing after sync

**Causes:**
- Site creation failed
- Quote doesn't have a site in simPRO
- Association API call failed

**Solution:**
1. Check if quote has a site in simPRO
2. Check log file for site creation errors
3. Manually associate site in HubSpot

---

## 📈 After Successful Test

Once the test passes, you have two options:

### Option A: Continue with Residential Deals Only

Sync all ~11,582 residential deals:

```bash
ruby master_full_sync.rb \
  --pipeline=default \
  --verbose
```

**Estimated Time:** 1.5-2 hours

---

### Option B: Sync All Pipelines

Sync all 11,582+ deals across all pipelines:

```bash
ruby master_full_sync.rb --verbose
```

**Estimated Time:** 2-3 hours

---

## 🎯 Recommended Next Steps

1. ✅ **Complete this test** (10 deals, 5 minutes)
2. ✅ **Verify in HubSpot** (10 minutes)
3. ✅ **Fix any issues** (if needed)
4. ✅ **Run full residential sync** (1-2 hours)
5. ✅ **Verify sample of results** (15 minutes)
6. ✅ **Create HubSpot reports** to validate data
7. ✅ **Document any edge cases** found

---

## 🔥 Quick Start Commands

Copy/paste these commands for the full workflow:

```bash
# 1. Navigate to sync directory
cd /Users/alexmoore/Development/Solarhub-simpro-hubspot/solar-hub-simpro/one-time-sync

# 2. Pre-flight check
./test_sync_locally.sh

# 3. Test sync (10 deals)
ruby test_residential_sync.rb

# 4. If successful, run full residential sync
ruby master_full_sync.rb --pipeline=default --verbose

# 5. Or run full sync (all pipelines)
ruby master_full_sync.rb --verbose
```

---

## 📞 Support

**If you encounter issues:**

1. Check the log file: `sync_YYYYMMDD_HHMMSS.log`
2. Review error messages in console output
3. Verify environment variables are set
4. Check API connectivity
5. Review HubSpot property names

---

## ✨ Summary

**Test Approach:**
- Test with 10 deals first
- Verify results thoroughly
- Then run full sync on all 11,582 deals

**What Gets Updated:**
- 90+ new deal properties
- All line items (with new calculations)
- Site associations (fixing 99.9% missing)
- Contact associations (fixing 30% missing)

**Safety:**
- No duplication (find-or-update logic)
- Preserves existing data (pipeline, stage, owner)
- Can resume from any point
- Comprehensive logging

**Ready to begin?** 🚀

```bash
cd one-time-sync
ruby test_residential_sync.rb
```

---

**Prepared by:** AI Assistant  
**Date:** November 25, 2025  
**Test Duration:** 5 minutes  
**Full Sync Duration:** 1-2 hours








