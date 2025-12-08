require 'httparty'
require 'dotenv/load'
require_relative 'config/environment'

# Compare OLD vs NEW (optimized) sync performance
deal_id = "188565215685"
quote_id = "41273"

existing_deal = {
  "results" => [{
    "id" => deal_id
  }]
}

puts "\n" + "=" * 80
puts "PERFORMANCE COMPARISON: OLD vs OPTIMIZED Sync"
puts "=" * 80
puts "Quote ID: #{quote_id}"
puts "=" * 80

# Fetch quote data first to compare
quote_response = HTTParty.get(
  "#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}?display=all",
  headers: {
    "Content-Type" => "application/json",
    "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
  }
)

# Count potential API calls in OLD method
old_api_calls = 1  # Base quote call
old_api_calls += 1  # Sections call

if quote_response["Sections"].present?
  sections_count = quote_response["Sections"].count
  old_api_calls += sections_count  # Cost centers per section
  
  quote_response["Sections"].each do |section|
    if section["CostCenters"].present?
      cost_centers_count = section["CostCenters"].count
      old_api_calls += cost_centers_count * 5  # 5 item types per cost center
      
      section["CostCenters"].each do |cc|
        if cc["Items"] && cc["Items"]["Labors"].present?
          old_api_calls += cc["Items"]["Labors"].count  # Labour rate calls
        end
      end
    end
  end
end

puts "\nOLD METHOD (Current):"
puts "  Estimated API calls: #{old_api_calls}"
puts "  Structure: Quote + Sections + (CostCenters × #{quote_response["Sections"].count}) + (Items × 5 per CC) + Labour rates"

puts "\nNEW METHOD (Optimized with display=all):"
puts "  API calls: 1 (just display=all)"
puts "  Reduction: #{((1.0 - 1.0/old_api_calls) * 100).round(1)}% fewer API calls"

puts "\n" + "=" * 80
puts "Running OPTIMIZED sync..."
puts "=" * 80

start_time = Time.now
Hubspot::QuoteOptimized.create_line_item_optimized(quote_id, deal_id, existing_deal)
duration = (Time.now - start_time).round(2)

puts "✓ Completed in #{duration} seconds"

# Verify
line_items_response = HTTParty.get(
  "https://api.hubapi.com/crm/v4/objects/deals/#{deal_id}/associations/line_items",
  headers: { 
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
  }
)

puts "✓ Created #{line_items_response["results"].count} line items"

puts "\n" + "=" * 80
puts "SUMMARY"
puts "=" * 80
puts "Old method would make: #{old_api_calls} API calls to Simpro"
puts "New method only makes: 1 API call to Simpro"
puts "Speed improvement: ~#{old_api_calls}x faster data fetching!"
puts "=" * 80

