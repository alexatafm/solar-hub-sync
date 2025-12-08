#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../config/environment'
require 'httparty'

deal_ids = ARGV.empty? ? ['189141778891', '188308429271'] : ARGV

deal_ids.each do |deal_id|
  puts "="*80
  puts "Deal ID: #{deal_id}"
  puts "="*80
  
  deal = HTTParty.get(
    "https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}",
    query: { 
      properties: 'dealname,simpro_quote_id,amount,simpro_net_price_inc_tax,simpro_discount_amount_inc_tax,simpro_final_total_after_stcs' 
    },
    headers: {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
    }
  )
  
  if deal['properties']
    props = deal['properties']
    puts "Deal Name: #{props['dealname']}"
    puts "Quote ID: #{props['simpro_quote_id']}"
    puts "Amount: $#{props['amount']}"
    puts "Net Price (Inc Tax): $#{props['simpro_net_price_inc_tax']}"
    puts "Discount Amount (Inc Tax): $#{props['simpro_discount_amount_inc_tax']}"
    puts "Final Total After STCs: $#{props['simpro_final_total_after_stcs']}"
    
    # Get line items
    line_items = HTTParty.get(
      "https://api.hubapi.com/crm/v4/objects/deals/#{deal_id}/associations/line_items",
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      }
    )
    
    line_item_count = line_items['results']&.count || 0
    puts "Line Items: #{line_item_count}"
    
    if line_item_count > 0
      puts "\nSample Line Items (first 5):"
      line_items['results'].first(5).each_with_index do |li, idx|
        li_id = li['toObjectId']
        li_details = HTTParty.get(
          "https://api.hubapi.com/crm/v3/objects/line_items/#{li_id}",
          query: { 
            properties: 'name,quantity,price,discounted_price_inc_tax,discounted_price_ex_tax,section,costcenter,type' 
          },
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
          }
        )
        
        if li_details['properties']
          p = li_details['properties']
          puts "  #{idx + 1}. #{p['name']}"
          puts "     Section: #{p['section']} | Cost Center: #{p['costcenter']}"
          puts "     Price: $#{p['price']} | Qty: #{p['quantity']}"
          puts "     Discounted (Inc): $#{p['discounted_price_inc_tax']} | Discounted (Ex): $#{p['discounted_price_ex_tax']}"
        end
      end
    end
    
    puts "\n"
  else
    puts "Deal not found or error: #{deal.inspect}"
  end
end

