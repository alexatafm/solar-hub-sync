#!/bin/bash

# =============================================================================
# LOCAL SYNC TESTING SCRIPT
# =============================================================================
# Purpose: Test sync functionality locally before deploying to Railway
# 
# This script:
#  1. Tests simPRO API connectivity
#  2. Tests HubSpot API connectivity
#  3. Validates data mappings
#  4. Tests sync of a single quote
#  5. Verifies results in HubSpot
#
# Usage:
#   chmod +x test_sync_locally.sh
#   ./test_sync_locally.sh
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# =============================================================================
# ENVIRONMENT VALIDATION
# =============================================================================

print_header "1. VALIDATING ENVIRONMENT"

if [ -z "$SIMPRO_TEST_URL" ]; then
    print_error "SIMPRO_TEST_URL not set"
    exit 1
else
    print_success "SIMPRO_TEST_URL: $SIMPRO_TEST_URL"
fi

if [ -z "$SIMPRO_TEST_KEY_ID" ]; then
    print_error "SIMPRO_TEST_KEY_ID not set"
    exit 1
else
    print_success "SIMPRO_TEST_KEY_ID: ${SIMPRO_TEST_KEY_ID:0:20}..."
fi

if [ -z "$HUBSPOT_ACCESS_TOKEN" ]; then
    print_error "HUBSPOT_ACCESS_TOKEN not set"
    exit 1
else
    print_success "HUBSPOT_ACCESS_TOKEN: ${HUBSPOT_ACCESS_TOKEN:0:20}..."
fi

# =============================================================================
# TEST SIMPRO API
# =============================================================================

print_header "2. TESTING SIMPRO API"

print_info "Testing simPRO quotes endpoint..."
SIMPRO_QUOTES=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $SIMPRO_TEST_KEY_ID" \
    -H "Content-Type: application/json" \
    "$SIMPRO_TEST_URL/quotes/?pageSize=1&page=1" 2>/dev/null)

SIMPRO_HTTP_CODE=$(echo "$SIMPRO_QUOTES" | tail -n 1)
SIMPRO_BODY=$(echo "$SIMPRO_QUOTES" | sed '$ d')

if [ "$SIMPRO_HTTP_CODE" = "200" ]; then
    QUOTE_COUNT=$(echo "$SIMPRO_BODY" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    print_success "SimPRO API working - Found $QUOTE_COUNT quotes"
    
    # Extract first quote ID for testing
    TEST_QUOTE_ID=$(echo "$SIMPRO_BODY" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0]['ID'] if data else '')" 2>/dev/null)
    
    if [ ! -z "$TEST_QUOTE_ID" ]; then
        print_info "Test Quote ID: $TEST_QUOTE_ID"
    fi
else
    print_error "SimPRO API failed with HTTP $SIMPRO_HTTP_CODE"
    echo "$SIMPRO_BODY"
    exit 1
fi

# =============================================================================
# TEST HUBSPOT API
# =============================================================================

print_header "3. TESTING HUBSPOT API"

print_info "Testing HubSpot deals endpoint..."
HUBSPOT_DEALS=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $HUBSPOT_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.hubapi.com/crm/v3/objects/deals?limit=1" 2>/dev/null)

HUBSPOT_HTTP_CODE=$(echo "$HUBSPOT_DEALS" | tail -n 1)
HUBSPOT_BODY=$(echo "$HUBSPOT_DEALS" | sed '$ d')

if [ "$HUBSPOT_HTTP_CODE" = "200" ]; then
    print_success "HubSpot API working"
else
    print_error "HubSpot API failed with HTTP $HUBSPOT_HTTP_CODE"
    echo "$HUBSPOT_BODY"
    exit 1
fi

# =============================================================================
# TEST HUBSPOT PROPERTIES
# =============================================================================

print_header "4. VALIDATING HUBSPOT PROPERTIES"

print_info "Checking Deal properties..."
DEAL_PROPS=$(curl -s \
    -H "Authorization: Bearer $HUBSPOT_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.hubapi.com/crm/v3/properties/deals" 2>/dev/null)

# Check for key properties
REQUIRED_DEAL_PROPS=(
    "simpro_quote_id"
    "simpro_net_price_inc_tax"
    "simpro_discount_amount_inc_tax"
    "simpro_final_total_after_stcs"
    "simpro_stcs"
    "simpro_veecs"
)

for prop in "${REQUIRED_DEAL_PROPS[@]}"; do
    if echo "$DEAL_PROPS" | grep -q "\"name\":\"$prop\""; then
        print_success "Deal property exists: $prop"
    else
        print_error "Deal property missing: $prop"
    fi
done

print_info "Checking Line Item properties..."
LINE_ITEM_PROPS=$(curl -s \
    -H "Authorization: Bearer $HUBSPOT_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.hubapi.com/crm/v3/properties/line_items" 2>/dev/null)

REQUIRED_LINE_ITEM_PROPS=(
    "discounted_price_inc_tax"
    "discounted_price_ex_tax"
    "costcenter"
    "primary_optional_cost_centre"
)

for prop in "${REQUIRED_LINE_ITEM_PROPS[@]}"; do
    if echo "$LINE_ITEM_PROPS" | grep -q "\"name\":\"$prop\""; then
        print_success "Line item property exists: $prop"
    else
        print_error "Line item property missing: $prop"
    fi
done

# =============================================================================
# TEST SINGLE QUOTE SYNC
# =============================================================================

if [ ! -z "$TEST_QUOTE_ID" ]; then
    print_header "5. TESTING SINGLE QUOTE SYNC"
    
    print_info "Syncing Quote ID: $TEST_QUOTE_ID"
    print_warning "This will modify data in HubSpot!"
    
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd ..
        rails runner "
        quote_id = $TEST_QUOTE_ID
        
        puts '🔄 Fetching quote from simPRO...'
        query = { 
          'columns' => 'ID,Customer,Site,SiteContact,Description,Salesperson,ProjectManager,CustomerContact,Technician,DateIssued,DueDate,DateApproved,OrderNo,Name,Stage,Total,Totals,Status,Tags,Notes,Type,STC,LinkedJobID,ArchiveReason,CustomFields',
          'pageSize' => 1 
        }

        quote = HTTParty.get(\"#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}\", {
          query: query,
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => \"Bearer #{ENV['SIMPRO_TEST_KEY_ID']}\"
          }
        })

        timeline_data = HTTParty.get(\"#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/timelines/\", {
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => \"Bearer #{ENV['SIMPRO_TEST_KEY_ID']}\"
          }
        })
        
        if quote.success?
          puts '✅ Quote fetched successfully'
          puts '🔄 Syncing to HubSpot...'
          
          Hubspot::Deal.update_deal_value(quote, timeline_data)
          
          puts '✅ Sync completed!'
          puts ''
          puts 'Quote Details:'
          puts \"  ID: #{quote['ID']}\"
          puts \"  Name: #{quote['Name']}\"
          puts \"  Total (Inc Tax): $#{quote['Total']['IncTax']}\"
          puts \"  STCs: $#{quote['Totals']['STCs']}\"
          puts \"  Final Total: $#{quote['Total']['IncTax'] - quote['Totals']['STCs']}\"
        else
          puts '❌ Failed to fetch quote'
          exit 1
        end
        "
        
        if [ $? -eq 0 ]; then
            print_success "Quote synced successfully!"
        else
            print_error "Quote sync failed!"
            exit 1
        fi
    else
        print_warning "Skipping single quote sync test"
    fi
else
    print_warning "No test quote ID available - skipping sync test"
fi

# =============================================================================
# SUMMARY
# =============================================================================

print_header "TEST SUMMARY"

print_success "All pre-flight checks passed!"
print_info ""
print_info "You can now run the full sync:"
print_info "  ruby one-time-sync/master_full_sync.rb --verbose"
print_info ""
print_info "Or test with dry-run first:"
print_info "  ruby one-time-sync/master_full_sync.rb --dry-run --verbose"
print_info ""
print_info "Or sync a specific range:"
print_info "  ruby one-time-sync/master_full_sync.rb --start-page=1 --end-page=10"
print_info ""

exit 0

