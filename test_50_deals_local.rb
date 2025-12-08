#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to find 50 quotes with existing deals and sync them locally
# This ensures we're testing actual sync operations, not just skipping

require_relative '../config/environment'
require 'httparty'

puts "Finding 50 quotes with existing deals..."
puts "="*80

found_quotes = []
page = 1
max_pages = 20  # Search up to 20 pages

while found_quotes.count < 50 && page <= max_pages
  quotes = HTTParty.get(
    "#{ENV['SIMPRO_TEST_URL']}/quotes/?columns=ID&page=#{page}&pageSize=50",
    headers: {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
    }
  )
  
  break if quotes.nil? || quotes.empty?
  
  quotes.each do |quote|
    quote_id = quote['ID']
    deal = Hubspot::Deal.find_deal(quote_id)
    
    if deal && deal['results'] && deal['results'].any?
      found_quotes << quote_id
      puts "Found quote #{quote_id} (#{found_quotes.count}/50)"
      
      break if found_quotes.count >= 50
    end
  end
  
  page += 1
  sleep(0.5)  # Rate limiting
end

if found_quotes.empty?
  puts "ERROR: No quotes with existing deals found!"
  exit 1
end

puts ""
puts "Found #{found_quotes.count} quotes with deals"
puts "Running sync test..."
puts "="*80
puts ""

# Create a temporary CSV file with these quotes
require 'csv'
csv_file = "test_50_quotes_#{Time.now.strftime('%Y%m%d_%H%M%S')}.csv"
CSV.open(csv_file, 'w') do |csv|
  csv << ['record_id', 'simpro_quote_id', 'deal_name']
  found_quotes.each do |quote_id|
    deal = Hubspot::Deal.find_deal(quote_id)
    if deal && deal['results'] && deal['results'].any?
      deal_id = deal['results'].first['id']
      deal_name = deal['results'].first['properties']['dealname'] || "Quote #{quote_id}"
      csv << [deal_id, quote_id, deal_name]
    end
  end
end

puts "Created test CSV: #{csv_file}"
puts "Now running master_full_sync.rb with these quotes..."
puts ""

# For now, let's just run the sync on these quotes directly
# We'll modify master_full_sync to accept quote IDs or use a different approach

# Actually, let's create a simpler approach - modify master_full_sync to accept a quote list
# Or we can just run it normally and it will process whatever quotes it finds

puts "To test with these quotes, you can:"
puts "1. Run: bundle exec ruby one-time-sync/master_full_sync.rb --start-page=1 --end-page=1 --page-size=50"
puts "2. Or modify master_full_sync.rb to accept a quote ID list"
puts ""
puts "For now, running a direct test on first 10 quotes..."
puts ""

found_quotes.first(10).each_with_index do |quote_id, idx|
  puts "[#{idx + 1}/10] Testing quote #{quote_id}..."
  system("bundle exec ruby one-time-sync/test_single_quote.rb #{quote_id} 2>&1 | tail -5")
  puts ""
end

