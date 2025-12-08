# Duplicate Quote ID Investigation Report

## Summary

**Total Deals:** 11,582  
**Unique Quote IDs:** 11,063  
**Duplicate Quote IDs:** 415  
**Total Duplicate Deals:** 519 (11,582 - 11,063)

## Key Findings

### 1. Pattern Analysis

**Deal Name Patterns:**
- **410 duplicates** (98.8%) have **IDENTICAL deal names**
- **5 duplicates** have some empty/incomplete names
- **0 duplicates** have genuinely different names

**Amount Patterns:**
- **100% of duplicates** have the **SAME amount**
- This confirms they're referencing the same quote

**Pipeline & Stage:**
- All duplicates checked are in the **same pipeline** (`default`)
- All duplicates checked are in the **same stage** (`closedwon`)

### 2. Root Cause Analysis

**Most Likely Causes:**

1. **Multiple Sync Runs**
   - Same quote synced multiple times, creating duplicate deals
   - Each sync created a new deal instead of updating existing one
   - Record IDs are very different (created at different times)

2. **Data Import Issues**
   - Bulk imports may have created duplicates
   - Some deals have incomplete names (e.g., "54303 -" vs "54303 - 1219 Shannons Flat Road")
   - Suggests some were created before full data was available

3. **Test/Development Data**
   - Some duplicates include test deals (e.g., "Gabbytest Testinghub", "Sean HubspotTest16")
   - These should be cleaned up separately

### 3. Examples

**Example 1: Quote 54574 (3 deals)**
- All 3 deals: Identical name, amount, pipeline, stage
- Record IDs: 187665604035, 189145372109, 189145372121
- **Conclusion:** True duplicates - same quote synced 3 times

**Example 2: Quote 54303 (2 deals)**
- Deal 1: "54303 - 1219 Shannons Flat Road, Murrumbucca" (complete)
- Deal 2: "54303 -" (incomplete name)
- Same amount, pipeline, stage
- **Conclusion:** One deal created before full data was available

**Example 3: Quote 51003 (4 deals)**
- All 4 deals: Identical name, amount, pipeline, stage
- Record IDs span a wide range
- **Conclusion:** Quote synced 4 separate times

### 4. Record ID Patterns

- **Sequential IDs (<1000 apart):** 3 examples
  - Created very close together (likely same sync run)
- **Very Different IDs:** 46+ examples
  - Created at different times (likely multiple sync runs)

### 5. Impact Assessment

**Current State:**
- 415 quote IDs have duplicates
- 519 extra deals exist (should be 11,063 deals, not 11,582)
- All duplicates reference the same SimPRO quote
- Sync will update ALL duplicates if `--duplicates=all` is used

**Recommendation:**
- Use `--duplicates=first` (default) to sync only one deal per quote ID
- This will sync 11,063 unique quotes
- The duplicate deals will remain in HubSpot but won't be updated
- Consider a cleanup script later to merge/delete duplicates

### 6. Sync Strategy

**Recommended Approach:**
1. **Default behavior:** `--duplicates=first`
   - Syncs the first occurrence of each quote ID
   - Prevents updating duplicate deals
   - Most efficient and safe

2. **Alternative:** `--duplicates=all`
   - Syncs all deals even with duplicate quote IDs
   - Will update all 11,582 deals
   - May cause confusion if duplicates exist

3. **Skip mode:** `--duplicates=skip`
   - Skips all duplicates entirely
   - Not recommended - will miss valid deals

## Conclusion

The duplicates are **legitimate duplicate deals in HubSpot** that reference the same SimPRO quote. They were likely created from:
- Multiple sync runs
- Bulk imports
- Incomplete initial syncs (hence empty names)

**Action:** Use `--duplicates=first` to sync only unique quotes. The duplicate deals will remain in HubSpot but won't be updated during sync.

