#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# TEST RESIDENTIAL PIPELINE SYNC
# =============================================================================
# Purpose: Test sync of 10 residential pipeline deals
# 
# This script:
#  - Only syncs deals in the "default" (Residential Sales) pipeline
#  - Tests with first 10 matching deals
#  - Provides detailed verification output
#
# Usage:
#   ruby test_residential_sync.rb
# =============================================================================

require_relative '../config/environment'

puts "="*80
puts "🏠 RESIDENTIAL PIPELINE TEST SYNC"
puts "="*80
puts ""
puts "Configuration:"
puts "  Pipeline: Residential Sales (default)"
puts "  Test Size: 10 deals"
puts "  Line Items: Will be recreated with new calculations"
puts "="*80
puts ""

# Statistics
stats = {
  total_checked: 0,
  residential_found: 0,
  synced: 0,
  failed: 0,
  skipped_non_residential: 0
}

start_time = Time.now

# Fetch quotes from simPRO
page = 1
page_size = 50
synced_count = 0
target_count = 10

puts "🔍 Searching for residential pipeline deals..."
puts ""

loop do
  break if synced_count >= target_count
  
  # Fetch page of quotes
  query = { 
    'columns' => 'ID,Name,Status',
    'page' => page,
    'pageSize' => page_size
  }
  
  quotes_response = HTTParty.get(
    "#{ENV['SIMPRO_TEST_URL']}/quotes/",
    query: query,
    headers: {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
    }
  )
  
  break unless quotes_response.success? && quotes_response.any?
  
  puts "📄 Checking page #{page} (#{quotes_response.count} quotes)..."
  
  quotes_response.each do |quote|
    stats[:total_checked] += 1
    quote_id = quote['ID']
    
    # Find existing deal in HubSpot
    existing_deal = Hubspot::Deal.find_deal(quote_id)
    
    if existing_deal && existing_deal['results'] && existing_deal['results'].any?
      deal = existing_deal['results'].first
      pipeline = deal['properties']['pipeline'] rescue nil
      deal_name = deal['properties']['dealname'] rescue "Quote #{quote_id}"
      
      if pipeline == 'default'
        stats[:residential_found] += 1
        
        puts ""
        puts "-"*80
        puts "✅ RESIDENTIAL DEAL FOUND: #{quote_id} - #{deal_name}"
        puts "-"*80
        
        # Sync this deal
        begin
          # Fetch full quote data
          full_query = { 
            'columns' => 'ID,Customer,Site,SiteContact,Description,Salesperson,ProjectManager,CustomerContact,Technician,DateIssued,DueDate,DateApproved,OrderNo,Name,Stage,Total,Totals,Status,Tags,Notes,Type,STC,LinkedJobID,ArchiveReason,CustomFields',
            'pageSize' => 1 
          }
          
          quote_full = HTTParty.get(
            "#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}",
            query: full_query,
            headers: {
              'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
            }
          )
          
          timeline_data = HTTParty.get(
            "#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/timelines/",
            headers: {
              'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
            }
          )
          
          if quote_full.success?
            puts "  🔄 Syncing to HubSpot..."
            
            # This will UPDATE the existing deal
            Hubspot::Deal.update_deal_value(quote_full, timeline_data)
            
            stats[:synced] += 1
            synced_count += 1
            
            puts "  ✅ Sync complete! (#{synced_count}/#{target_count})"
            
            # Show what was updated
            puts ""
            puts "  📊 Quote Details:"
            puts "    Total (Inc Tax): $#{quote_full['Total']['IncTax']}"
            puts "    STCs: $#{quote_full['Totals']['STCs']}"
            puts "    VEECs: $#{quote_full['Totals']['VEECs']}"
            puts "    Final Total: $#{quote_full['Total']['IncTax'] - quote_full['Totals']['STCs'] - quote_full['Totals']['VEECs']}"
            
          else
            stats[:failed] += 1
            puts "  ❌ Failed to fetch full quote data"
          end
          
        rescue => e
          stats[:failed] += 1
          puts "  ❌ Error syncing: #{e.message}"
        end
        
        # Stop if we've synced enough
        break if synced_count >= target_count
        
      else
        stats[:skipped_non_residential] += 1
        # Skip non-residential deals quietly
      end
    else
      # Quote doesn't exist in HubSpot yet - skip for now
    end
  end
  
  break if synced_count >= target_count
  page += 1
  
  # Safety: don't check more than 20 pages
  break if page > 20
end

elapsed = Time.now - start_time

puts ""
puts "="*80
puts "📊 TEST SYNC SUMMARY"
puts "="*80
puts "  Time Elapsed: #{elapsed.round(2)} seconds"
puts ""
puts "  Quotes Checked: #{stats[:total_checked]}"
puts "  Residential Deals Found: #{stats[:residential_found]}"
puts "  Non-Residential Skipped: #{stats[:skipped_non_residential]}"
puts ""
puts "  ✅ Successfully Synced: #{stats[:synced]}"
puts "  ❌ Failed: #{stats[:failed]}"
puts ""
puts "="*80
puts ""

if stats[:synced] > 0
  puts "🎉 SUCCESS! #{stats[:synced]} residential deals updated."
  puts ""
  puts "📋 NEXT STEPS - VERIFY IN HUBSPOT:"
  puts ""
  puts "1. Go to HubSpot Deals"
  puts "2. Filter by: Pipeline = 'Residential Sales'"
  puts "3. Sort by: 'Last Modified Date' (newest first)"
  puts "4. Open the top #{stats[:synced]} deals"
  puts ""
  puts "✅ Check these fields are NOW populated:"
  puts "   - simPRO Net Price (Inc Tax)"
  puts "   - Simpro Discount Amount (Inc Tax)"
  puts "   - simPRO STCs"
  puts "   - simPRO VEECs"
  puts "   - simPRO Total Inc Tax"
  puts "   - simPRO Materials Cost (Estimate)"
  puts "   - simPRO Project Manager"
  puts "   - Plus 80+ other new fields!"
  puts ""
  puts "✅ Check Line Items:"
  puts "   - Open Line Items tab"
  puts "   - Verify 'Discounted Price (Inc Tax)' is populated"
  puts "   - Sum should match 'Final Total After STCs'"
  puts ""
  puts "✅ Check Associations:"
  puts "   - Associations tab should show:"
  puts "     • Contact"
  puts "     • Site (if quote has a site)"
  puts "     • Line Items"
  puts ""
  puts "If everything looks good, run full sync:"
  puts "  ruby master_full_sync.rb --verbose"
  puts ""
else
  puts "⚠️  No deals synced. This might mean:"
  puts "  - No residential deals found in first #{page-1} pages"
  puts "  - All checked deals were non-residential"
  puts "  - API issues"
  puts ""
  puts "Check the output above for details."
end

puts "="*80








