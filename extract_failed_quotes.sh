#!/bin/bash
# Extract Failed Quotes for Manual Review

echo "======================================================================"
echo "FAILED QUOTES EXTRACTION TOOL"
echo "======================================================================"
echo ""

OUTPUT_FILE="failed_quotes_$(date +%Y%m%d_%H%M%S).txt"

echo "Extracting failed quote IDs from logs..."
echo ""

# Extract quote IDs that had real errors (not broken pipe)
{
  echo "FAILED QUOTES - Manual Review Required"
  echo "Generated: $(date)"
  echo "======================================================================"
  echo ""
  
  echo "1. QUOTES WITH SSL ERRORS:"
  echo "----------------------------------------------------------------------"
  grep -B2 "SSL" sync_*.log 2>/dev/null | grep "quote_id=" | sed 's/.*quote_id=\([0-9]*\).*/\1/' | sort -u
  
  echo ""
  echo ""
  echo "2. QUOTES WITH OTHER ERRORS (excluding Broken Pipe):"
  echo "----------------------------------------------------------------------"
  grep -i "error syncing quote" sync_*.log 2>/dev/null | grep -v "Broken pipe" | sed 's/.*quote_id=\([0-9]*\).*/\1/' | sort -u
  
  echo ""
  echo ""
  echo "3. ALL ERROR SUMMARY:"
  echo "----------------------------------------------------------------------"
  # Get the error summary sections
  grep -A100 "ERRORS (" sync_*.log 2>/dev/null | grep "Quote " | sed 's/.*Quote //' | sort -u
  
  echo ""
  echo ""
  echo "4. DETAILED ERROR MESSAGES:"
  echo "----------------------------------------------------------------------"
  grep -B1 -A1 "error_message=" sync_*.log 2>/dev/null | grep -v "Broken pipe"
  
} > "$OUTPUT_FILE"

cat "$OUTPUT_FILE"

echo ""
echo "======================================================================"
echo "Output saved to: $OUTPUT_FILE"
echo "======================================================================"
echo ""

# Count unique failed quotes
unique_count=$(grep -A100 "ERRORS (" sync_*.log 2>/dev/null | grep "Quote " | sed 's/.*Quote //' | sort -u | wc -l | tr -d ' ')

echo "Summary:"
echo "  - Unique failed quotes: $unique_count"
echo "  - Report saved to: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Review the quote IDs in $OUTPUT_FILE"
echo "  2. Check if these quotes still need to be synced"
echo "  3. Manually retry if necessary using: ruby master_full_sync.rb --quote-id=XXXXX"
echo ""

