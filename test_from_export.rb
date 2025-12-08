#!/usr/bin/env ruby
require_relative '../config/environment'
require 'csv'

puts "="*80
puts "🧪 TESTING SYNC FROM EXPORT (5 DEALS)"
puts "="*80
puts ""

# Read CSV and get first 5 deals with Quote IDs
puts "📄 Reading export file..."
deals = CSV.read("all-deals 5.csv", headers: true, encoding: 'UTF-8')

# Find first 5 deals with simPRO Quote ID
test_deals = deals.select { |d| d["Simpro Quote Id"].to_s.strip != "" }.first(5)

puts "✅ Found #{test_deals.count} deals to test"
puts ""

test_deals.each_with_index do |deal, index|
  deal_id = deal["Record ID"]
  quote_id = deal["Simpro Quote Id"]
  deal_name = deal["Deal Name"]
  
  puts "="*80
  puts "🔄 SYNCING #{index + 1}/5"
  puts "="*80
  puts "  Deal ID: #{deal_id}"
  puts "  Quote ID: #{quote_id}"
  puts "  Name: #{deal_name}"
  puts ""
  
  begin
    # Fetch full quote from simPRO
    query = { 
      'columns' => 'ID,Customer,Site,SiteContact,Description,Salesperson,ProjectManager,CustomerContact,Technician,DateIssued,DueDate,DateApproved,OrderNo,Name,Stage,Total,Totals,Status,Tags,Notes,Type,STC,LinkedJobID,ArchiveReason,CustomFields',
      'pageSize' => 1 
    }
    
    quote = HTTParty.get(
      "#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}",
      query: query,
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
    
    if quote.success?
      puts "  ✅ Fetched quote from simPRO"
      puts "     Total (Inc Tax): $#{quote['Total']['IncTax']}"
      puts "     STCs: $#{quote['Totals']['STCs']}"
      puts ""
      
      # Sync to HubSpot
      puts "  🔄 Syncing to HubSpot..."
      Hubspot::Deal.update_deal_value(quote, timeline_data)
      
      puts "  ✅ SYNC COMPLETE!"
      puts ""
      
    else
      puts "  ❌ Failed to fetch quote: #{quote.code}"
      puts ""
      break
    end
    
  rescue => e
    puts "  ❌ ERROR: #{e.message}"
    puts "  #{e.backtrace.first(3).join("\n  ")}"
    puts ""
    break
  end
  
  # Small delay between syncs
  sleep(2) unless index == test_deals.count - 1
end

puts "="*80
puts "✅ TEST COMPLETE"
puts "="*80
puts ""
puts "📋 NEXT: Check these deals in HubSpot"
puts ""
test_deals.each do |deal|
  puts "  • #{deal['Deal Name']} (Quote #{deal['Simpro Quote Id']})"
end
puts ""
