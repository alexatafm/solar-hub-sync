#!/usr/bin/env ruby
# frozen_string_literal: true

# Manual test script for quote 55884
# Shows what would happen during sync without actually creating/updating deal

require_relative '../config/environment'
require 'httparty'

quote_id = ARGV[0] || '55884'

puts "="*80
puts "MANUAL QUOTE TEST - Quote ID: #{quote_id}"
puts "="*80
puts ""

# Fetch quote with display=all
puts "Step 1: Fetching quote with display=all..."
quote = HTTParty.get(
  "#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}?display=all",
  headers: {
    "Content-Type" => "application/json",
    "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
  },
  timeout: 30
)

unless quote.success?
  puts "ERROR: Failed to fetch quote - #{quote.code}"
  exit 1
end

quote_data = quote.parsed_response

puts "✓ Quote fetched successfully"
puts "  Quote ID: #{quote_data['ID']}"
puts "  Quote Name: #{quote_data['Name'] || '[empty]'}"
puts "  Site Name: #{quote_data.dig('Site', 'Name') || '[empty]'}"
puts "  Customer: #{quote_data.dig('Customer', 'GivenName') || quote_data.dig('Customer', 'CompanyName') || '[empty]'}"
puts "  Total Ex Tax: $#{quote_data.dig('Total', 'ExTax') || 0}"
puts "  Total Inc Tax: $#{quote_data.dig('Total', 'IncTax') || 0}"
puts ""

# Calculate expected deal name
quote_name = quote_data['Name'].to_s.strip
if quote_name.present?
  deal_name = quote_data['ID'].to_s + " - " + quote_name
else
  site_name = quote_data.dig('Site', 'Name').to_s.strip rescue ""
  if site_name.present?
    deal_name = quote_data['ID'].to_s + " - " + site_name
  else
    deal_name = quote_data['ID'].to_s
  end
end

puts "Step 2: Expected Deal Name"
puts "  #{deal_name}"
puts ""

# Verify quote structure
puts "Step 3: Verifying quote structure..."
has_sections = quote_data['Sections'].present?
section_count = quote_data['Sections']&.count || 0

puts "  Has Sections: #{has_sections ? '✓' : '✗'}"
puts "  Section Count: #{section_count}"

if has_sections
  total_cost_centers = 0
  total_items = 0
  cost_center_details = []
  
  quote_data['Sections'].each do |section|
    section_id = section['ID']
    section_name = section['Name']
    
    section['CostCenters']&.each do |cc|
      cost_center_id = cc['ID']
      cost_center_name = cc.dig('CostCenter', 'Name') || cc['Name'] rescue ""
      is_optional = cc['OptionalDepartment'] == true
      
      items = cc['Items'] || {}
      item_count = 0
      ['Catalogs', 'OneOffs', 'Prebuilds', 'ServiceFees', 'Labors'].each do |item_type|
        item_count += (items[item_type] || []).count
      end
      
      total_cost_centers += 1
      total_items += item_count
      
      cost_center_details << {
        name: cost_center_name,
        optional: is_optional,
        items: item_count,
        total_inc: cc.dig('Total', 'IncTax') || 0,
        total_ex: cc.dig('Total', 'ExTax') || 0
      }
    end
  end
  
  puts "  Total Cost Centers: #{total_cost_centers}"
  puts "  Total Items: #{total_items}"
  puts ""
  puts "  Cost Center Breakdown:"
  cost_center_details.each_with_index do |cc, idx|
    puts "    #{idx + 1}. #{cc[:name]} (#{cc[:optional] ? 'Optional' : 'Primary'})"
    puts "       Items: #{cc[:items]} | Total Inc: $#{cc[:total_inc]} | Total Ex: $#{cc[:total_ex]}"
  end
else
  puts "  ✗ Quote missing Sections - cannot sync line items!"
end

puts ""

# Calculate what deal properties would be
puts "Step 4: Expected Deal Properties"
net_price_inc_tax = 0
if quote_data['Sections']
  quote_data['Sections'].each do |section|
    section['CostCenters']&.each do |cc|
      next if cc['OptionalDepartment']
      items = cc['Items'] || {}
      ['Catalogs', 'OneOffs', 'Prebuilds', 'ServiceFees', 'Labors'].each do |item_type|
        (items[item_type] || []).each do |item|
          net_price_inc_tax += item.dig('Total', 'Amount', 'IncTax') || 0
        end
      end
    end
  end
end

adjusted_ex_tax = quote_data.dig('Totals', 'Adjusted', 'Estimate') || 0
discount_amount_inc_tax = (adjusted_ex_tax * 1.1).abs.round(2) rescue 0
total_inc_tax = quote_data.dig('Total', 'IncTax') || 0
stcs = quote_data.dig('Totals', 'STCs') || 0
final_total_after_stcs = (total_inc_tax - stcs).round(2)

puts "  Amount (Ex Tax): $#{quote_data.dig('Total', 'ExTax') || 0}"
puts "  Net Price (Inc Tax): $#{net_price_inc_tax.round(2)}"
puts "  Discount Amount (Inc Tax): $#{discount_amount_inc_tax}"
puts "  Final Total After STCs: $#{final_total_after_stcs}"
puts "  STCs: $#{stcs}"
puts ""

# Check if deal exists
puts "Step 5: Checking for existing deal in HubSpot..."
existing_deal = Hubspot::Deal.find_deal(quote_id)

if existing_deal && existing_deal['results'] && existing_deal['results'].any?
  deal = existing_deal['results'].first
  deal_id = deal['id']
  puts "  ✓ Deal found: #{deal_id}"
  puts "  Current Deal Name: #{deal['properties']['dealname']}"
  puts ""
  puts "  Would update deal with new name: #{deal_name}"
else
  puts "  ✗ Deal not found in HubSpot"
  puts "  Would create deal with name: #{deal_name}"
end

puts ""
puts "="*80
puts "MANUAL TEST COMPLETE"
puts "="*80

