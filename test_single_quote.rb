#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# SINGLE QUOTE TEST SCRIPT
# =============================================================================
# Purpose: Test the updated quote sync logic with a single quote
# 
# Usage:
#   ruby test_single_quote.rb QUOTE_ID
#
# Example:
#   ruby test_single_quote.rb 12345
# =============================================================================

require 'httparty'
require 'json'
require 'logger'

# Load Rails environment
require_relative '../config/environment'

class SingleQuoteTest
  def initialize(quote_id)
    @quote_id = quote_id
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] [#{severity}] #{msg}\n"
    end
  end

  def run
    @logger.info "="*80
    @logger.info "SINGLE QUOTE TEST - Quote ID: #{@quote_id}"
    @logger.info "="*80
    @logger.info ""

    # Check environment variables
    unless ENV['SIMPRO_TEST_URL'] && ENV['SIMPRO_TEST_KEY_ID'] && ENV['HUBSPOT_ACCESS_TOKEN']
      @logger.error "Missing required environment variables!"
      @logger.error "Required: SIMPRO_TEST_URL, SIMPRO_TEST_KEY_ID, HUBSPOT_ACCESS_TOKEN"
      exit 1
    end

    # Step 1: Fetch quote with display=all
    @logger.info "Step 1: Fetching quote with display=all..."
    quote = fetch_quote_with_display_all
    
    unless quote&.success?
      @logger.error "Failed to fetch quote: #{quote&.code || 'Unknown error'}"
      exit 1
    end

    quote_data = quote.parsed_response
    @logger.info "✓ Quote fetched successfully"
    @logger.info "  Quote ID: #{quote_data['ID']}"
    @logger.info "  Quote Name: #{quote_data['Name']}"
    @logger.info "  Total Ex Tax: $#{quote_data.dig('Total', 'ExTax')}"
    @logger.info ""

    # Step 2: Verify quote has Sections/CostCenters/Items
    @logger.info "Step 2: Verifying quote structure..."
    verify_quote_structure(quote_data)
    @logger.info ""

    # Step 3: Check if deal exists in HubSpot
    @logger.info "Step 3: Checking for existing deal in HubSpot..."
    existing_deal = Hubspot::Deal.find_deal(@quote_id)
    
    if existing_deal && existing_deal['results'] && existing_deal['results'].any?
      deal = existing_deal['results'].first
      deal_id = deal['id']
      @logger.info "✓ Deal found in HubSpot"
      @logger.info "  Deal ID: #{deal_id}"
      @logger.info "  Deal Name: #{deal['properties']['dealname']}"
      @logger.info "  Pipeline: #{deal['properties']['pipeline']}"
      @logger.info ""
    else
      @logger.error "✗ Deal not found in HubSpot for quote #{@quote_id}"
      @logger.error "  Cannot proceed with sync test - deal must exist first"
      exit 1
    end

    # Step 4: Count existing line items
    @logger.info "Step 4: Counting existing line items..."
    existing_line_items = HTTParty.get(
      "https://api.hubapi.com/crm/v4/objects/deals/#{deal_id}/associations/line_items",
      headers: {
        'Content-Type' => 'application/json',
        "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      }
    )
    
    existing_count = existing_line_items['results']&.count || 0
    @logger.info "  Existing line items: #{existing_count}"
    @logger.info ""

    # Step 5: Fetch timeline data
    @logger.info "Step 5: Fetching timeline data..."
    timeline_data = fetch_timeline_data
    @logger.info "✓ Timeline data fetched"
    @logger.info ""

    # Step 6: Run the sync
    @logger.info "Step 6: Running sync (this will update deal and line items)..."
    @logger.info "-"*80
    
    sync_start = Time.now
    Hubspot::Deal.update_deal_value(quote_data, timeline_data)
    sync_duration = Time.now - sync_start
    
    @logger.info "-"*80
    @logger.info "✓ Sync completed in #{sync_duration.round(2)} seconds"
    @logger.info ""

    # Step 7: Verify results
    @logger.info "Step 7: Verifying sync results..."
    verify_sync_results(deal_id, existing_count, quote_data)
    
    @logger.info ""
    @logger.info "="*80
    @logger.info "TEST COMPLETE"
    @logger.info "="*80
  end

  private

  def fetch_quote_with_display_all
    HTTParty.get(
      "#{ENV['SIMPRO_TEST_URL']}/quotes/#{@quote_id}?display=all",
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      },
      timeout: 30
    )
  rescue => e
    @logger.error "Error fetching quote: #{e.message}"
    nil
  end

  def fetch_timeline_data
    HTTParty.get(
      "#{ENV['SIMPRO_TEST_URL']}/quotes/#{@quote_id}/timelines/",
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      },
      timeout: 30
    ).parsed_response
  rescue => e
    @logger.warn "Error fetching timeline: #{e.message}"
    nil
  end

  def verify_quote_structure(quote_data)
    has_sections = quote_data['Sections'].present?
    section_count = quote_data['Sections']&.count || 0
    
    @logger.info "  Has Sections: #{has_sections ? '✓' : '✗'}"
    @logger.info "  Section Count: #{section_count}"
    
    if has_sections
      total_cost_centers = 0
      total_items = 0
      
      quote_data['Sections'].each do |section|
        cost_centers = section['CostCenters'] || []
        total_cost_centers += cost_centers.count
        
        cost_centers.each do |cc|
          items = cc['Items'] || {}
          ['Catalogs', 'OneOffs', 'Prebuilds', 'ServiceFees', 'Labors'].each do |item_type|
            total_items += (items[item_type] || []).count
          end
        end
      end
      
      @logger.info "  Total Cost Centers: #{total_cost_centers}"
      @logger.info "  Total Items: #{total_items}"
      
      unless has_sections && total_items > 0
        @logger.warn "  ⚠ Warning: Quote has sections but no items found"
      end
    else
      @logger.error "  ✗ Quote missing Sections - cannot sync line items!"
      exit 1
    end
  end

  def verify_sync_results(deal_id, previous_line_item_count, quote_data)
    # Check updated line items
    line_items_response = HTTParty.get(
      "https://api.hubapi.com/crm/v4/objects/deals/#{deal_id}/associations/line_items",
      headers: {
        'Content-Type' => 'application/json',
        "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      }
    )
    
    new_line_items = line_items_response['results'] || []
    new_count = new_line_items.count
    
    @logger.info "  Previous line items: #{previous_line_item_count}"
    @logger.info "  New line items: #{new_count}"
    @logger.info "  Change: #{new_count - previous_line_item_count}"
    
    if new_count > 0
      @logger.info ""
      @logger.info "  Sample line items (first 5):"
      new_line_items.first(5).each_with_index do |li, idx|
        li_id = li['toObjectId']
        li_details = HTTParty.get(
          "https://api.hubapi.com/crm/v3/objects/line_items/#{li_id}",
          query: { properties: 'name,quantity,price,discounted_price_inc_tax,discounted_price_ex_tax,section,costcenter' },
          headers: {
            'Content-Type' => 'application/json',
            "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
          }
        )
        
        if li_details['properties']
          props = li_details['properties']
          @logger.info "    #{idx + 1}. #{props['name']} | Qty: #{props['quantity']} | Price: $#{props['price']} | Discounted Inc: $#{props['discounted_price_inc_tax']} | Section: #{props['section']}"
        end
      end
    end
    
    # Verify deal properties were updated
    deal_response = HTTParty.get(
      "https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}",
      query: { properties: 'dealname,amount,simpro_quote_id,simpro_net_price_inc_tax,simpro_discount_amount_inc_tax' },
      headers: {
        'Content-Type' => 'application/json',
        "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      }
    )
    
    if deal_response['properties']
      props = deal_response['properties']
      @logger.info ""
      @logger.info "  Deal Properties Updated:"
      @logger.info "    Amount: $#{props['amount']}"
      @logger.info "    Net Price (Inc Tax): $#{props['simpro_net_price_inc_tax']}"
      @logger.info "    Discount Amount (Inc Tax): $#{props['simpro_discount_amount_inc_tax']}"
    end
  end
end

# Main execution
if __FILE__ == $0
  if ARGV.empty?
    puts "Usage: ruby test_single_quote.rb QUOTE_ID"
    puts ""
    puts "Example:"
    puts "  ruby test_single_quote.rb 12345"
    exit 1
  end

  quote_id = ARGV[0].to_i
  
  if quote_id == 0
    puts "Error: Invalid quote ID. Please provide a numeric quote ID."
    exit 1
  end

  test = SingleQuoteTest.new(quote_id)
  
  begin
    test.run
  rescue Interrupt
    puts "\n\nTest interrupted by user"
    exit 1
  rescue => e
    puts "\n\nError: #{e.message}"
    puts e.backtrace.join("\n")
    exit 1
  end
end

