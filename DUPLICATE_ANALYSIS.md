# CSV Duplicate Analysis Report

## Summary

**CSV File:** `hubspot-crm-exports-all-deals-2025-11-28.csv`  
**Total Deals:** 11,583  
**Unique Quote IDs:** 11,064  
**Duplicate Quote IDs:** 415

## Duplicate Quote IDs

**Issue:** 415 quote IDs appear multiple times in the CSV (some quotes have 2-4 deals associated)

**Examples:**
- Quote ID `51003`: 4 deals
- Quote ID `54780`: 3 deals  
- Quote ID `54927`: 3 deals
- Quote ID `55459`: 3 deals
- Quote ID `54574`: 3 deals

**Handling Strategy:**
The sync script now supports three modes via `--duplicates` flag:
- `first` (default): Only sync the first occurrence of each quote ID
- `all`: Sync all deals even if they share the same quote ID
- `skip`: Skip all duplicates entirely

## Deal Name Similarity

No exact duplicate deal names found. Some very similar names exist (likely same property with slight variations in formatting).

## CSV Structure

```
Record ID, Deal Name, Simpro Quote Id, Amount
```

- **Record ID:** HubSpot Deal ID (unique)
- **Deal Name:** Deal name in HubSpot
- **Simpro Quote Id:** Quote ID from SimPRO (can be duplicated)
- **Amount:** Deal amount

## Updated Sync Script

The `master_full_sync.rb` script now:
1. Reads from CSV file instead of SimPRO API pagination
2. Handles duplicate quote IDs based on `--duplicates` flag
3. Uses deal IDs from CSV (more reliable than searching by quote ID)
4. Maintains elegant logging for Railway observability

