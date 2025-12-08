# Duplicate Merge Plan

## Confirmation: SimPRO Update

**YES** - The sync WILL update SimPRO CustomField 229 (HubSpot Deal ID):

1. **Location:** `app/models/hubspot/quote.rb` line 86
2. **Method:** `Simpro::Quote.update_deal_id(deal_id, quote["ID"])`
3. **Custom Field:** SimPRO CustomField ID 229
4. **Updated Logic:** Now ALWAYS updates (not just if blank) to ensure correct deal ID after duplicate cleanup

## Merge Strategy

**Found:** 415 duplicate quote IDs with 519 duplicate deals total

**Process:**
1. For each duplicate quote ID, keep the "best" deal:
   - Prefers deals with complete names (not just "Quote ID -")
   - If all have complete names, keeps the first one
2. Remove duplicates:
   - Option 1: Archive (safer, can recover)
   - Option 2: Delete (permanent)

## Execution Steps

### Step 1: Dry Run (Preview)
```bash
cd one-time-sync
bundle exec ruby merge_duplicates.rb --dry-run
```

### Step 2: Archive Duplicates (Safer)
```bash
bundle exec ruby merge_duplicates.rb --archive-only
```

### Step 3: Delete Duplicates (Permanent)
```bash
bundle exec ruby merge_duplicates.rb
```

### Step 4: Verify
After merging, re-export from HubSpot to verify only 1 deal per quote ID remains.

### Step 5: Run Full Sync
```bash
bundle exec ruby master_full_sync.rb --duplicates=first
```

This will:
- Sync all 11,063 unique quotes
- Update SimPRO CustomField 229 with the correct HubSpot Deal ID
- Ensure each quote points to the single remaining deal

## Expected Results

**Before:**
- 11,582 deals
- 415 duplicate quote IDs
- Some SimPRO quotes may have wrong/old deal IDs

**After Merge:**
- ~11,063 deals (1 per quote ID)
- 0 duplicate quote IDs
- Clean starting point

**After Sync:**
- All SimPRO quotes updated with correct HubSpot Deal ID
- All deals synced with latest quote data
- No confusion from duplicates

