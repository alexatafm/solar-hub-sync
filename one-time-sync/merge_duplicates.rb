#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# DUPLICATE DEAL MERGER
# =============================================================================
# Purpose: Merge duplicate deals in HubSpot so each quote ID has only 1 deal
# 
# Strategy:
# - For each duplicate quote ID, keep the "best" deal (complete name, most data)
# - Archive/delete the other duplicates
# - This ensures SimPRO gets updated with the correct single deal ID during sync
#
# Usage:
#   bundle exec ruby merge_duplicates.rb [--dry-run] [--archive-only]
# =============================================================================

require_relative '../config/environment'
require 'httparty'
require 'csv'
require 'optparse'

class DuplicateMerger
  def initialize(dry_run: false, archive_only: false)
    @dry_run = dry_run
    @archive_only = archive_only
    @stats = {
      duplicates_found: 0,
      deals_kept: 0,
      deals_archived: 0,
      deals_deleted: 0,
      errors: []
    }
  end

  def run
    puts "="*80
    puts "DUPLICATE DEAL MERGER"
    puts "="*80
    puts "Mode: #{@dry_run ? 'DRY RUN' : 'LIVE'}"
    puts "Archive Only: #{@archive_only ? 'Yes' : 'No (will delete)'}"
    puts "="*80
    puts ""

    # Load CSV and find duplicates
    duplicates = find_duplicates
    
    if duplicates.empty?
      puts "No duplicates found!"
      return
    end

    puts "Found #{duplicates.count} quote IDs with duplicates"
    puts "Total duplicate deals to process: #{duplicates.values.sum { |d| d.count - 1 }}"
    puts ""

    # Process each duplicate group
    duplicates.each_with_index do |(quote_id, deals), index|
      # Resume logic removed - all duplicates processed
      
      puts "[#{index + 1}/#{duplicates.count}] Processing Quote ID: #{quote_id} (#{deals.count} deals)"
      
      # Determine which deal to keep
      deal_to_keep = select_best_deal(deals, quote_id)
      deals_to_remove = deals - [deal_to_keep]
      
      puts "  Keeping: Deal #{deal_to_keep[:record_id]} - #{deal_to_keep[:deal_name]}"
      
      # Process duplicates
      deals_to_remove.each do |deal|
        if @dry_run
          puts "  [DRY RUN] Would remove: Deal #{deal[:record_id]} - #{deal[:deal_name]}"
        else
          remove_duplicate_deal(deal, deal_to_keep)
        end
      end
      
      @stats[:duplicates_found] += 1
      @stats[:deals_kept] += 1
      puts ""
      
      sleep(0.5)  # Rate limiting
    end

    # Print summary
    print_summary
  end

  private

  def find_duplicates
    csv_file = 'hubspot-crm-exports-all-deals-2025-11-28.csv'
    csv_path = File.expand_path(csv_file, File.dirname(__FILE__))
    
    unless File.exist?(csv_path)
      raise "CSV file not found: #{csv_path}"
    end

    quotes = {}
    
    CSV.foreach(csv_path, headers: true) do |row|
      quote_id = row['Simpro Quote Id']&.strip
      next if quote_id.nil? || quote_id.empty?
      
      deal = {
        record_id: row['Record ID']&.strip,
        deal_name: row['Deal Name']&.strip,
        amount: row['Amount']&.strip,
        simpro_quote_id: quote_id
      }
      
      quotes[quote_id] ||= []
      quotes[quote_id] << deal
    end

    # Return only duplicates
    quotes.select { |_qid, deals| deals.count > 1 }
  end

  def select_best_deal(deals, quote_id)
    # Strategy: Prefer deal with complete name (not just "Quote ID -" or empty)
    complete_names = deals.select do |d|
      name = d[:deal_name].to_s.strip
      name.present? && !name.match?(/^#{quote_id}\s*-\s*$/) && name.length > (quote_id.length + 5)
    end
    
    if complete_names.any?
      # If multiple complete names, prefer the one that appears first (likely original)
      complete_names.first
    else
      # If all incomplete, prefer non-empty over empty
      non_empty = deals.select { |d| d[:deal_name].to_s.strip.present? }
      non_empty.any? ? non_empty.first : deals.first
    end
  end

  def remove_duplicate_deal(deal, deal_to_keep)
    deal_id = deal[:record_id]
    quote_id = deal_to_keep[:simpro_quote_id] || 'unknown'
    
    begin
      # Verify deal exists and has the same quote ID
      deal_info = HTTParty.get(
        "https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}",
        query: { properties: 'simpro_quote_id,dealname' },
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
        }
      )
      
      unless deal_info.success?
        puts "  ⚠ Skipping: Deal #{deal_id} not found (may already be deleted)"
        return
      end
      
      # Verify it's actually a duplicate (same quote ID)
      deal_quote_id = deal_info['properties']['simpro_quote_id']
      unless deal_quote_id == quote_id
        puts "  ⚠ Skipping: Deal #{deal_id} has different quote ID (#{deal_quote_id} vs #{quote_id})"
        return
      end
      
      if @archive_only
        # Archive the deal (safer - can be recovered)
        archive_deal(deal_id)
        @stats[:deals_archived] += 1
        puts "  ✓ Archived: Deal #{deal_id} - #{deal[:deal_name]}"
      else
        # Delete the deal (permanent)
        delete_deal(deal_id)
        @stats[:deals_deleted] += 1
        puts "  ✓ Deleted: Deal #{deal_id} - #{deal[:deal_name]}"
      end
      
    rescue => e
      @stats[:errors] << {
        deal_id: deal_id,
        quote_id: quote_id,
        error: e.message
      }
      puts "  ✗ Error removing Deal #{deal_id}: #{e.message}"
    end
  end

  def archive_deal(deal_id)
    # Archive by setting dealstage to closedlost with a reason
    body_json = {
      "properties" => {
        "dealstage" => "closedlost",
        "closed_lost_reason" => "Duplicate - Merged"
      }
    }
    
    response = HTTParty.patch(
      "https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}",
      body: body_json.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      }
    )
    
    unless response.success?
      raise "Failed to archive deal: #{response.code} - #{response.body[0..200]}"
    end
  end

  def delete_deal(deal_id)
    response = HTTParty.delete(
      "https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}",
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      }
    )
    
    unless response.success?
      raise "Failed to delete deal: #{response.code} - #{response.body[0..200]}"
    end
  end

  def print_summary
    puts "="*80
    puts "MERGE SUMMARY"
    puts "="*80
    puts "Duplicate Quote IDs Processed: #{@stats[:duplicates_found]}"
    puts "Deals Kept: #{@stats[:deals_kept]}"
    puts "Deals Archived: #{@stats[:deals_archived]}" if @archive_only
    puts "Deals Deleted: #{@stats[:deals_deleted]}" unless @archive_only
    puts "Errors: #{@stats[:errors].count}"
    
    if @stats[:errors].any?
      puts ""
      puts "Errors:"
      @stats[:errors].each do |err|
        puts "  Deal #{err[:deal_id]}: #{err[:error]}"
      end
    end
    
    puts "="*80
  end
end

# Parse options
options = { dry_run: false, archive_only: false }

OptionParser.new do |opts|
  opts.banner = "Usage: merge_duplicates.rb [OPTIONS]"
  
  opts.on("--dry-run", "Preview changes without making them") do
    options[:dry_run] = true
  end
  
  opts.on("--archive-only", "Archive duplicates instead of deleting") do
    options[:archive_only] = true
  end
  
  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

# Run merger
merger = DuplicateMerger.new(
  dry_run: options[:dry_run],
  archive_only: options[:archive_only]
)

begin
  merger.run
rescue => e
  puts "FATAL ERROR: #{e.message}"
  puts e.backtrace.join("\n")
  exit 1
end

