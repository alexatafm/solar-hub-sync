# Master Full Sync Changes Summary

## What Changed

### Original Version (Before Update)

The `master_full_sync.rb` script was fetching quotes with a **limited column set**:

```ruby
query = { 
  "columns" => "ID,Customer,Site,SiteContact,Description,Salesperson,ProjectManager,CustomerContact,Technician,DateIssued,DueDate,DateApproved,OrderNo,Name,Stage,Total,Totals,Status,Tags,Notes,Type,STC,LinkedJobID,ArchiveReason,CustomFields",
  "pageSize" => 1 
}

quote = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}", {
  query: query,
  headers: { ... }
})
```

**Problem:** This limited column set did **NOT** include:
- `Sections` (quote sections)
- `CostCenters` (cost centers within sections)
- `Items` (line items within cost centers: Catalogs, OneOffs, Prebuilds, ServiceFees, Labors)

When this quote data was passed to `Hubspot::Deal.update_deal_value()`, it would then call `Hubspot::Quote.create_line_item()`, which would **fetch the quote again** with `display=all` to get the full data needed for line item processing.

### Updated Version (After Update)

The script now fetches quotes with `display=all` directly:

```ruby
# Fetch quote with display=all to get full data including Sections/CostCenters/Items
# This matches the updated quote sync logic that processes line items from Sections
quote = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}?display=all", {
  headers: {
    "Content-Type" => "application/json",
    "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
  }
})
```

**Benefits:**
1. ✅ Quote data includes all Sections/CostCenters/Items from the start
2. ✅ Ensures compatibility with updated quote sync logic
3. ✅ More efficient (though there's still a redundant fetch inside `create_line_item` - that's a Rails model optimization for later)

## Updated Quote Sync Logic Features

The updated quote sync logic (in `app/models/hubspot/quote.rb`) includes:

1. **Cost-Center-Specific Discount Ratios**
   - Calculates discount ratios per cost center
   - Applies discounts proportionally within each cost center

2. **STCs/VEECs Handling**
   - Detects hot water cost centers
   - Subtracts STCs/VEECs from hot water totals only
   - Other cost centers unaffected

3. **Discounted Price Calculations**
   - `discounted_price_inc_tax` - Price after discounts and STCs/VEECs
   - `discounted_price_ex_tax` - Ex-tax version
   - Applied per line item using cost-center ratios

4. **Section/CostCenter Structure**
   - Processes quote structure: Sections → CostCenters → Items
   - Handles all item types: Catalogs, OneOffs, Prebuilds, ServiceFees, Labors
   - Tracks section and cost center IDs/names

5. **Optional Department Handling**
   - Uses `OptionalDepartment` flag (not `Billable`)
   - Marks items as "Primary" or "Optional"

## Testing

Use the test script to verify with a single quote:

```bash
cd one-time-sync
ruby test_single_quote.rb QUOTE_ID
```

The test script will:
1. Fetch quote with `display=all`
2. Verify quote has Sections/CostCenters/Items
3. Check if deal exists in HubSpot
4. Count existing line items
5. Run the sync
6. Verify results (line items created, deal properties updated)

## Files Changed

- `one-time-sync/master_full_sync.rb` - Updated to use `display=all`
- `one-time-sync/test_single_quote.rb` - New test script

## Files Using Updated Logic

- `app/models/hubspot/quote.rb` - Contains the updated line item sync logic
- `app/models/hubspot/deal.rb` - Calls the quote sync logic
- `one-time-sync/master_full_sync.rb` - Uses the Rails models with updated logic

