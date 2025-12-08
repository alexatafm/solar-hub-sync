# 🚀 START HERE - Test 10 Residential Deals

## ⚡ Quick Start (5 minutes)

```bash
# Step 1: Go to sync directory
cd /Users/alexmoore/Development/Solarhub-simpro-hubspot/solar-hub-simpro/one-time-sync

# Step 2: Run test
ruby test_residential_sync.rb
```

**That's it!** The script will:
- ✅ Find 10 residential pipeline deals
- ✅ Update all 90+ new properties
- ✅ Fix Site associations
- ✅ Recalculate line items

---

## 📊 What You Discovered

From your HubSpot export analysis:

| Metric | Current | After Full Sync |
|--------|---------|----------------|
| Total Deals | 11,583 | 11,583 |
| With simPRO Quote ID | 11,582 (99.99%) | 11,582 (100%) |
| New Properties Populated | 3 (0.0%) | ➡️ **11,582 (100%)** |
| With Site Associations | 10 (0.1%) | ➡️ **11,582 (100%)** |
| With Contact Associations | 8,071 (69.7%) | ➡️ **11,582 (100%)** |
| Line Items with Discounts | 0 (0%) | ➡️ **~150,000 (100%)** |

**This is an UPDATE sync, not a CREATE sync!**

---

## ✅ Test Checklist

After running `test_residential_sync.rb`, verify in HubSpot:

### 1. Open Any Synced Deal

**Filter:** Pipeline = Residential Sales  
**Sort:** Last Modified (newest first)

### 2. Check These Fields Are NOW Populated:

- [ ] simPRO Net Price (Inc Tax)
- [ ] Simpro Discount Amount (Inc Tax)
- [ ] simPRO STCs
- [ ] simPRO VEECs
- [ ] simPRO Total Inc Tax
- [ ] simPRO Materials Cost (Estimate)
- [ ] simPRO Project Manager
- [ ] Plus 80+ more!

### 3. Check Line Items Tab:

- [ ] "Discounted Price (Inc Tax)" column visible
- [ ] All line items have this field populated
- [ ] Sum matches deal total (minus STCs)

### 4. Check Associations Tab:

- [ ] Contact associated ✅
- [ ] **Site associated** ✅ (was missing before!)
- [ ] Line items listed ✅

---

## 🎯 If Test Passes

Run full sync on all 11,582 residential deals:

```bash
ruby master_full_sync.rb --pipeline=default --verbose
```

**Duration:** 1-2 hours  
**Will update:** All 11,582 deals with new properties

---

## 📖 Full Documentation

- **Test Guide:** `RESIDENTIAL_TEST_GUIDE.md` - Detailed test instructions
- **Strategy:** `../docs/EXISTING_DEALS_UPDATE_STRATEGY.md` - What we're doing and why
- **Mapping:** `../docs/MASTER_DATA_SYNC_MAPPING.md` - All field mappings

---

## 🔥 Ready?

```bash
cd /Users/alexmoore/Development/Solarhub-simpro-hubspot/solar-hub-simpro/one-time-sync
ruby test_residential_sync.rb
```

Then check HubSpot! 🎉








