#!/bin/bash

# =============================================================================
# TEST SCRIPT FOR MASTER SYNC V2
# =============================================================================
# Purpose: Quick test to validate sync works before production run
# Usage: ./test_sync_v2.sh
# =============================================================================

set -e  # Exit on error

echo "======================================================================"
echo "MASTER SYNC V2 - PRE-DEPLOYMENT TEST"
echo "======================================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Check environment variables
echo "Step 1: Checking environment variables..."
echo "----------------------------------------------------------------------"

if [ -z "$SIMPRO_TEST_URL" ]; then
    echo -e "${RED}❌ SIMPRO_TEST_URL not set${NC}"
    echo "   Export it with: export SIMPRO_TEST_URL='https://solarhub.simprosuite.com/api/v1.0/companies/4'"
    exit 1
else
    echo -e "${GREEN}✅ SIMPRO_TEST_URL set${NC}"
fi

if [ -z "$SIMPRO_TEST_KEY_ID" ]; then
    echo -e "${RED}❌ SIMPRO_TEST_KEY_ID not set${NC}"
    echo "   Export it with: export SIMPRO_TEST_KEY_ID='your_key_here'"
    exit 1
else
    echo -e "${GREEN}✅ SIMPRO_TEST_KEY_ID set${NC}"
fi

if [ -z "$HUBSPOT_ACCESS_TOKEN" ]; then
    echo -e "${RED}❌ HUBSPOT_ACCESS_TOKEN not set${NC}"
    echo "   Export it with: export HUBSPOT_ACCESS_TOKEN='your_token_here'"
    exit 1
else
    echo -e "${GREEN}✅ HUBSPOT_ACCESS_TOKEN set${NC}"
fi

echo ""

# Step 2: Check CSV file exists
echo "Step 2: Checking CSV file..."
echo "----------------------------------------------------------------------"

CSV_FILE="hubspot-crm-exports-all-deals-2025-11-28.csv"
if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}❌ CSV file not found: $CSV_FILE${NC}"
    echo "   Please export deals from HubSpot and place in this directory"
    exit 1
else
    DEAL_COUNT=$(tail -n +2 "$CSV_FILE" | wc -l | tr -d ' ')
    FILE_SIZE=$(du -h "$CSV_FILE" | cut -f1)
    echo -e "${GREEN}✅ CSV file found${NC}"
    echo "   File: $CSV_FILE"
    echo "   Size: $FILE_SIZE"
    echo "   Deals: $DEAL_COUNT"
fi

echo ""

# Step 3: Check Ruby and dependencies
echo "Step 3: Checking Ruby environment..."
echo "----------------------------------------------------------------------"

if ! command -v ruby &> /dev/null; then
    echo -e "${RED}❌ Ruby not found${NC}"
    echo "   Install Ruby 3.0+ to continue"
    exit 1
else
    RUBY_VERSION=$(ruby -v)
    echo -e "${GREEN}✅ Ruby found: $RUBY_VERSION${NC}"
fi

echo ""

# Step 4: Check script exists
echo "Step 4: Checking sync script..."
echo "----------------------------------------------------------------------"

if [ ! -f "master_full_sync_v2.rb" ]; then
    echo -e "${RED}❌ Sync script not found: master_full_sync_v2.rb${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Sync script found${NC}"
    chmod +x master_full_sync_v2.rb
fi

echo ""

# Step 5: Test API connectivity
echo "Step 5: Testing API connectivity..."
echo "----------------------------------------------------------------------"

echo "Testing simPRO API..."
SIMPRO_TEST=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $SIMPRO_TEST_KEY_ID" \
    -H "Content-Type: application/json" \
    "$SIMPRO_TEST_URL/quotes/?pageSize=1" \
    --max-time 10)

if [ "$SIMPRO_TEST" = "200" ]; then
    echo -e "${GREEN}✅ simPRO API responding (HTTP 200)${NC}"
else
    echo -e "${RED}❌ simPRO API error (HTTP $SIMPRO_TEST)${NC}"
    echo "   Check your SIMPRO_TEST_KEY_ID"
    exit 1
fi

echo "Testing HubSpot API..."
HUBSPOT_TEST=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $HUBSPOT_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.hubapi.com/crm/v3/objects/deals?limit=1" \
    --max-time 10)

if [ "$HUBSPOT_TEST" = "200" ]; then
    echo -e "${GREEN}✅ HubSpot API responding (HTTP 200)${NC}"
else
    echo -e "${RED}❌ HubSpot API error (HTTP $HUBSPOT_TEST)${NC}"
    echo "   Check your HUBSPOT_ACCESS_TOKEN"
    exit 1
fi

echo ""

# Step 6: Run dry-run test
echo "Step 6: Running dry-run test (no changes)..."
echo "----------------------------------------------------------------------"
echo -e "${YELLOW}Running: ruby master_full_sync_v2.rb --limit=5 --dry-run --verbose${NC}"
echo ""

ruby master_full_sync_v2.rb --limit=5 --dry-run --verbose --csv-file="$CSV_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Dry-run completed successfully${NC}"
else
    echo ""
    echo -e "${RED}❌ Dry-run failed${NC}"
    exit 1
fi

echo ""

# Step 7: Run actual test with 5 deals
echo "Step 7: Running actual sync test (5 deals)..."
echo "----------------------------------------------------------------------"
echo -e "${YELLOW}This will sync 5 real deals to HubSpot${NC}"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Running: ruby master_full_sync_v2.rb --limit=5 --verbose${NC}"
    echo ""
    
    ruby master_full_sync_v2.rb --limit=5 --verbose --csv-file="$CSV_FILE"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Test sync completed successfully${NC}"
        echo ""
        echo "Check the following files for details:"
        echo "  - sync_*.log (detailed log)"
        echo "  - sync_*_report.csv (CSV report)"
        echo ""
        echo "Review the results in HubSpot and verify:"
        echo "  1. Deal properties updated correctly"
        echo "  2. Line items created with correct prices"
        echo "  3. Site associations exist"
        echo "  4. Contact/company associations exist"
        echo ""
        echo "If everything looks good, proceed with full sync:"
        echo "  ruby master_full_sync_v2.rb --verbose"
    else
        echo ""
        echo -e "${RED}❌ Test sync failed${NC}"
        echo "Check the log files for errors"
        exit 1
    fi
else
    echo "Test cancelled by user"
fi

echo ""
echo "======================================================================"
echo "TEST COMPLETE"
echo "======================================================================"

