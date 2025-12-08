require 'httparty'
require 'dotenv/load'
require_relative 'config/environment'

# Test the optimized version
deal_id = "188565215685"
quote_id = "41273"

puts "Testing OPTIMIZED Line Item Sync"
puts "=" * 80
puts "Deal ID: #{deal_id}"
puts "Quote ID: #{quote_id}"
puts "=" * 80

existing_deal = {
  "results" => [{
    "id" => deal_id
  }]
}

start_time = Time.now

# Call the optimized method
Hubspot::QuoteOptimized.create_line_item_optimized(quote_id, deal_id, existing_deal)

end_time = Time.now
duration = end_time - start_time

puts "\n" + "=" * 80
puts "✓ Sync completed in #{duration.round(2)} seconds"
puts "=" * 80

# Verify the line items
puts "\nVerifying line items in HubSpot..."
line_items_response = HTTParty.get(
  "https://api.hubapi.com/crm/v4/objects/deals/#{deal_id}/associations/line_items",
  headers: { 
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
  }
)

if line_items_response["results"].present?
  puts "✓ Found #{line_items_response["results"].count} line items"
  
  # Get first item details
  line_item_id = line_items_response["results"].first["toObjectId"]
  
  line_item_detail = HTTParty.get(
    "https://api.hubapi.com/crm/v3/objects/line_items/#{line_item_id}?properties=name,price,quantity,hs_sku,item_discount,line_total__ex_tax_,simpro_catalogue_id,billable_status,type",
    headers: { 
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
    }
  )
  
  puts "\nSample line item verification:"
  props = line_item_detail["properties"]
  puts "  Name: #{props["name"]}"
  puts "  Type: #{props["type"]}"
  puts "  SKU: #{props["hs_sku"]}"
  puts "  Price: $#{props["price"]} x #{props["quantity"]}"
  puts "  Line Total (Ex Tax): $#{props["line_total__ex_tax_"]}"
  puts "  Discount: #{props["item_discount"]}%"
  puts "  Simpro ID: #{props["simpro_catalogue_id"]}"
  puts "  Billable: #{props["billable_status"]}"
else
  puts "✗ No line items found!"
end

