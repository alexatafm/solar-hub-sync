# Logging Improvements for Railway Observability

## Overview

The logging system has been completely redesigned for elegant, structured logging that works perfectly with Railway's observability dashboards.

## Key Features

### 1. Structured Logging with Tags

All log messages now use structured tags for easy filtering:
- `[SYNC]` - General sync operations
- `[SUCCESS]` - Successful operations
- `[SKIP]` - Handled skips (not errors)
- `[ERROR]` - Actual errors that need attention
- `[WARN]` - Warnings
- `[PROGRESS]` - Progress updates with ETA
- `[DEBUG]` - Debug information (verbose mode only)

### 2. Clear Error Handling

**Before:** All errors logged as errors, even handled ones (404s, network timeouts)

**After:** 
- **Handled errors** (404s, network timeouts) → Logged as `[SKIP]` with clear reason
- **Actual errors** → Logged as `[ERROR]` with full context
- **Distinction:** Only real problems show as errors

### 3. Progress Tracking with ETA

Every quote sync shows:
- Current progress: `X/Y (Z%)`
- Remaining count
- **ETA** based on average time per deal
- Quote ID and name for context

Example:
```
[PROGRESS] 25/50 (50.0%) | 25 remaining | ETA: 1m 15s | quote_id=54693 | quote_name=27 Derribong Drive
```

### 4. Railway-Optimized Format

Logs are structured for Railway's log filtering:
- Timestamp format: `YYYY-MM-DD HH:MM:SS`
- Tag-based filtering: `[SYNC]`, `[ERROR]`, `[SUCCESS]`, etc.
- Key-value pairs: `key=value` format for easy parsing
- No emojis or special characters that break filtering

### 5. Comprehensive Summary

Final summary includes:
- Total processed, successful, failed, skipped, not found
- Performance metrics (avg, fastest, slowest, speed)
- Error list with full context
- Success rate percentage

## Log Examples

### Success
```
[2025-11-27 23:10:23] [SUCCESS] Quote synced successfully | quote_id=54693
```

### Skip (Handled)
```
[2025-11-27 23:10:23] [SKIP] Deal not found in HubSpot | quote_id=56841
[2025-11-27 23:10:23] [SKIP] Quote not found in SimPRO | quote_id=12345 | code=404
[2025-11-27 23:10:23] [SKIP] Network error fetching quote | quote_id=12345 | error=Timeout::Error | message=execution expired
```

### Error (Actual)
```
[2025-11-27 23:10:23] [ERROR] Error syncing quote | quote_id=12345 | error_class=RuntimeError | error_message=Unexpected error
```

### Progress
```
[2025-11-27 23:10:23] [PROGRESS] 25/50 (50.0%) | 25 remaining | ETA: 1m 15s | quote_id=54693 | quote_name=27 Derribong Drive
```

## Railway Dashboard Filtering

You can filter logs in Railway using:

**Success Rate:**
```
tag:SUCCESS
```

**Errors Only:**
```
tag:ERROR
```

**Skips (Handled):**
```
tag:SKIP
```

**Progress Updates:**
```
tag:PROGRESS
```

**Specific Quote:**
```
quote_id=54693
```

## Error Categories

### Handled (Logged as SKIP)
- Deal not found in HubSpot
- Quote not found in SimPRO (404)
- Network timeouts
- Pipeline filter mismatches

### Actual Errors (Logged as ERROR)
- Unexpected exceptions
- API errors (non-404)
- Data validation failures
- Sync logic errors

## Performance Metrics

The summary includes:
- **Total Time:** Human-readable format (e.g., "2h 15m")
- **Average:** Seconds per deal
- **Fastest/Slowest:** Performance bounds
- **Speed:** Deals per hour
- **Success Rate:** Percentage

## Testing

Run locally with:
```bash
bundle exec ruby one-time-sync/master_full_sync.rb --start-page=1 --end-page=1 --page-size=50
```

This will process 50 quotes and show all the improved logging in action.

