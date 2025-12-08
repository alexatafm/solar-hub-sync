#!/bin/bash
# Sync Audit Script
# Provides quick analysis of sync logs

echo "======================================================================"
echo "HISTORIC QUOTE SYNC - AUDIT TOOL"
echo "======================================================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if logs exist
if [ ! -f "sync_20251127_235026.log" ]; then
  echo -e "${RED}Error: Log files not found in current directory${NC}"
  exit 1
fi

echo "1. OVERALL STATISTICS"
echo "======================================================================"
for log in sync_*.log; do
  if [ -f "$log" ]; then
    echo ""
    echo "File: $log"
    echo "----------------------------------------------------------------------"
    grep "Total Processed:" "$log" | tail -1
    grep "Successful:" "$log" | tail -1
    grep "Failed:" "$log" | tail -1
    grep "Skipped:" "$log" | tail -1
    grep "Not Found:" "$log" | tail -1
    grep "Total Time:" "$log" | tail -1
    grep "Average:" "$log" | tail -1
    grep "Speed:" "$log" | tail -1
  fi
done

echo ""
echo ""
echo "2. ERROR ANALYSIS"
echo "======================================================================"
echo "Total Errors (excluding Broken Pipe):"
error_count=$(grep -i "ERROR" sync_*.log 2>/dev/null | grep -v "Broken pipe" | grep -v "ERRORS (" | wc -l | tr -d ' ')
echo "$error_count errors found"

if [ "$error_count" -gt 0 ]; then
  echo ""
  echo "Error Details:"
  grep -i "ERROR" sync_*.log 2>/dev/null | grep -v "Broken pipe" | grep -v "ERRORS (" | head -20
fi

echo ""
echo ""
echo "3. BROKEN PIPE ERRORS (Logging Issues)"
echo "======================================================================"
broken_pipe_count=$(grep "Broken pipe" sync_*.log 2>/dev/null | wc -l | tr -d ' ')
echo "$broken_pipe_count broken pipe errors (these are logging issues, not sync failures)"

echo ""
echo ""
echo "4. SUCCESS RATE"
echo "======================================================================"
success_count=$(grep -i "SUCCESS" sync_*.log 2>/dev/null | wc -l | tr -d ' ')
echo "Total successful syncs: $success_count"

echo ""
echo ""
echo "5. DUPLICATE HANDLING"
echo "======================================================================"
duplicate_count=$(grep "Skipping duplicate" sync_*.log 2>/dev/null | wc -l | tr -d ' ')
echo "Duplicates detected and skipped: $duplicate_count"

echo ""
echo ""
echo "6. NOT FOUND IN HUBSPOT"
echo "======================================================================"
not_found_count=$(grep "Deal not found in HubSpot" sync_*.log 2>/dev/null | wc -l | tr -d ' ')
echo "Quotes not found in HubSpot: $not_found_count"
echo "(These quotes exist in SimPro but not in HubSpot - expected behavior)"

echo ""
echo ""
echo "7. PERFORMANCE METRICS"
echo "======================================================================"
echo "Fastest sync times:"
grep "Fastest:" sync_*.log 2>/dev/null | tail -3

echo ""
echo "Slowest sync times:"
grep "Slowest:" sync_*.log 2>/dev/null | tail -3

echo ""
echo "Average speeds:"
grep "Speed:" sync_*.log 2>/dev/null | tail -3

echo ""
echo ""
echo "8. RECENT SUCCESSFUL SYNCS (Sample)"
echo "======================================================================"
grep "Quote synced successfully" sync_*.log 2>/dev/null | tail -10

echo ""
echo ""
echo "======================================================================"
echo "AUDIT COMPLETE"
echo "======================================================================"
echo ""
echo "For more detailed analysis, see: SYNC_AUDIT_REPORT.md"
echo ""
echo "Helpful commands:"
echo "  - View specific quote: grep 'quote_id=XXXXX' sync_*.log"
echo "  - Count by status: grep -E 'SUCCESS|FAILED|SKIP' sync_*.log | cut -d'[' -f4 | sort | uniq -c"
echo "  - Find slow syncs: grep 'PROGRESS' sync_*.log | grep -E '[5-9][0-9]\.[0-9]+s|[1-9][0-9][0-9]'"
echo ""

