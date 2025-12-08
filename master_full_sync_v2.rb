#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# MASTER FULL DATA SYNC SCRIPT V2
# =============================================================================
# Purpose: Comprehensive re-sync of ALL data from SimPRO to HubSpot
# 
# Includes:
#  - Full quote data sync (90+ properties)
#  - Line items with cost-center-based discount calculations
#  - Site and contact associations
#  - Enhanced structured logging for observability
#
# Updates from V1:
#  - Cost-center discount calculation (fixed Dec 8, 2025)
#  - Site association creation in HubSpot
#  - Contact association creation in HubSpot
#  - Structured CSV-style logging for reporting
#  - Enhanced error tracking and categorization
#
# Usage:
#   ruby master_full_sync_v2.rb [OPTIONS]
#
# Options:
#   --csv-file=FILE        CSV file path (default: hubspot-crm-exports-all-deals-2025-11-28.csv)
#   --start-index=N        Start from index N (default: 0)
#   --end-index=N          End at index N (default: all)
#   --limit=N              Limit to N deals (default: all)
#   --pipeline=PIPELINE    Filter by pipeline (default, 1012446696, 1011198445)
#   --dry-run              Preview actions without syncing
#   --verbose              Enable detailed logging
#   --skip-line-items      Skip line item sync (faster, deal data only)
#   --skip-associations    Skip creating site/contact associations
#
# Examples:
#   ruby master_full_sync_v2.rb --limit=100 --verbose
#   ruby master_full_sync_v2.rb --pipeline=default --verbose
# =============================================================================

require 'httparty'
require 'json'
require 'logger'
require 'optparse'
require 'csv'
require 'time'

# =============================================================================
# CONFIGURATION
# =============================================================================

class SyncConfig
  attr_accessor :csv_file, :start_index, :end_index, :limit, :dry_run, :verbose, 
                :pipeline_filter, :handle_duplicates, :skip_line_items, :skip_associations
  
  def initialize
    @csv_file = 'hubspot-crm-exports-all-deals-2025-11-28.csv'
    @start_index = 0
    @end_index = nil
    @limit = nil
    @dry_run = false
    @verbose = false
    @pipeline_filter = nil
    @handle_duplicates = 'first'
    @skip_line_items = false
    @skip_associations = false
  end
  
  def parse_args!
    OptionParser.new do |opts|
      opts.banner = "Usage: master_full_sync_v2.rb [OPTIONS]"
      
      opts.on("--csv-file=FILE", String, "CSV file path") { |f| @csv_file = f }
      opts.on("--start-index=N", Integer, "Start from index N") { |n| @start_index = n }
      opts.on("--end-index=N", Integer, "End at index N") { |n| @end_index = n }
      opts.on("--limit=N", Integer, "Limit to N deals") { |n| @limit = n }
      opts.on("--pipeline=PIPELINE", "Filter by pipeline") { |p| @pipeline_filter = p }
      opts.on("--duplicates=MODE", String, "Handle duplicates: first, all, skip") { |m| @handle_duplicates = m }
      opts.on("--dry-run", "Preview without syncing") { @dry_run = true }
      opts.on("--verbose", "Detailed logging") { @verbose = true }
      opts.on("--skip-line-items", "Skip line item sync") { @skip_line_items = true }
      opts.on("--skip-associations", "Skip site/contact associations") { @skip_associations = true }
      opts.on("-h", "--help", "Show help") { puts opts; exit }
    end.parse!
  end
end

# =============================================================================
# STRUCTURED LOGGING - Enhanced for Observability
# =============================================================================

class StructuredLogger
  LOG_LEVELS = {
    info: 'INFO',
    success: 'SUCCESS',
    warn: 'WARN',
    error: 'ERROR',
    skip: 'SKIP',
    progress: 'PROGRESS',
    debug: 'DEBUG'
  }
  
  def initialize(verbose: false)
    @verbose = verbose
    @start_time = Time.now
    
    # Console logger
    @console = Logger.new(STDOUT)
    @console.level = verbose ? Logger::DEBUG : Logger::INFO
    @console.formatter = proc { |severity, datetime, progname, msg| "#{msg}\n" }
    
    # File logger (detailed)
    log_filename = "sync_#{@start_time.strftime('%Y%m%d_%H%M%S')}.log"
    @file = Logger.new(log_filename)
    @file.level = Logger::DEBUG
    @file.formatter = proc { |severity, datetime, progname, msg| "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{msg}\n" }
    
    # CSV logger for easy analysis/reporting
    csv_filename = "sync_#{@start_time.strftime('%Y%m%d_%H%M%S')}_report.csv"
    @csv_file = File.open(csv_filename, 'w')
    @csv = CSV.new(@csv_file)
    @csv << ['Timestamp', 'Level', 'Event', 'Quote_ID', 'Deal_ID', 'Deal_Name', 'Duration_Sec', 'Line_Items', 'Associations', 'Status', 'Error_Class', 'Error_Message']
    
    # Statistics
    @stats = {
      deals_synced: 0,
      deals_failed: 0,
      deals_skipped: 0,
      deals_not_found: 0,
      line_items_created: 0,
      associations_created: 0,
      timings: [],
      errors: []
    }
    
    info "Log files created:", data: { 
      console_log: log_filename, 
      csv_report: csv_filename 
    }
  end
  
  def log(level, message, data: {})
    timestamp = Time.now
    formatted_time = timestamp.strftime('%Y-%m-%d %H:%M:%S')
    level_str = LOG_LEVELS[level] || 'INFO'
    
    # Build console/file message
    msg_parts = ["[#{formatted_time}]", "[#{level_str}]", message]
    
    if data.any?
      data_str = data.map { |k, v| "#{k}=#{format_value(v)}" }.join(" | ")
      msg_parts << "| #{data_str}"
    end
    
    full_message = msg_parts.join(" ")
    
    # Log to console and file
    case level
    when :error
      @console.error(full_message)
      @file.error(full_message)
    when :warn
      @console.warn(full_message)
      @file.warn(full_message)
    when :debug
      @console.debug(full_message) if @verbose
      @file.debug(full_message)
    else
      @console.info(full_message)
      @file.info(full_message)
    end
    
    # Log to CSV for specific events
    if [:success, :error, :skip].include?(level)
      log_to_csv(level, message, data, timestamp)
    end
  end
  
  def log_to_csv(level, message, data, timestamp)
    @csv << [
      timestamp.iso8601,
      LOG_LEVELS[level],
      message,
      data[:quote_id],
      data[:deal_id],
      data[:deal_name],
      data[:duration],
      data[:line_items],
      data[:associations],
      data[:status],
      data[:error_class],
      data[:error_message]
    ]
    @csv_file.flush  # Ensure data is written immediately
  end
  
  def format_value(value)
    case value
    when String
      value.length > 50 ? "#{value[0..47]}..." : value
    when Array
      value.join(',')
    else
      value.to_s
    end
  end
  
  def info(message, data: {})
    log(:info, message, data: data)
  end
  
  def success(message, data: {})
    log(:success, message, data: data)
  end
  
  def warn(message, data: {})
    log(:warn, message, data: data)
  end
  
  def error(message, data: {})
    log(:error, message, data: data)
  end
  
  def skip(message, data: {})
    log(:skip, message, data: data)
  end
  
  def debug(message, data: {})
    log(:debug, message, data: data)
  end
  
  def progress(current, total, data: {})
    percentage = ((current.to_f / total) * 100).round(1)
    remaining = total - current
    
    timings = @stats[:timings]
    avg_time = timings.any? ? timings.sum / timings.count : 3.0
    eta_seconds = remaining * avg_time
    eta_str = format_duration(eta_seconds)
    
    log(:progress, 
        "#{current}/#{total} (#{percentage}%) | Remaining: #{remaining} | ETA: #{eta_str}",
        data: data)
  end
  
  def increment(key, amount = 1)
    @stats[key] += amount
  end
  
  def add_timing(duration)
    @stats[:timings] << duration
  end
  
  def add_error(quote_id, error_class, error_message, deal_id: nil, backtrace: nil)
    @stats[:errors] << {
      quote_id: quote_id,
      deal_id: deal_id,
      error_class: error_class,
      error_message: error_message,
      timestamp: Time.now.iso8601,
      backtrace: backtrace&.first(5)
    }
  end
  
  def format_duration(seconds)
    return "0s" if seconds.nil? || seconds <= 0
    
    if seconds < 60
      "#{seconds.round(1)}s"
    elsif seconds < 3600
      minutes = (seconds / 60).floor
      secs = (seconds % 60).round
      "#{minutes}m #{secs}s"
    else
      hours = (seconds / 3600).floor
      minutes = ((seconds % 3600) / 60).floor
      "#{hours}h #{minutes}m"
    end
  end
  
  def print_summary
    elapsed = Time.now - @start_time
    total_processed = @stats[:deals_synced] + @stats[:deals_failed] + @stats[:deals_skipped] + @stats[:deals_not_found]
    success_rate = total_processed > 0 ? (@stats[:deals_synced].to_f / total_processed * 100).round(1) : 0
    avg_time = @stats[:timings].any? ? @stats[:timings].sum / @stats[:timings].count : 0
    
    info ""
    info "="*100
    info "SYNC SUMMARY REPORT"
    info "="*100
    info ""
    info "RESULTS:"
    info "  Total Processed:      #{total_processed}"
    info "  ✅ Successful:        #{@stats[:deals_synced]} (#{success_rate}%)"
    info "  ❌ Failed:            #{@stats[:deals_failed]}"
    info "  ⏭️  Skipped:           #{@stats[:deals_skipped]}"
    info "  🔍 Not Found:         #{@stats[:deals_not_found]}"
    info "  📦 Line Items Created: #{@stats[:line_items_created]}"
    info "  🔗 Associations:      #{@stats[:associations_created]}"
    info ""
    info "PERFORMANCE:"
    info "  Total Time:   #{format_duration(elapsed)}"
    info "  Average:      #{avg_time.round(2)}s per deal"
    
    if @stats[:timings].any?
      info "  Fastest:      #{@stats[:timings].min.round(2)}s"
      info "  Slowest:      #{@stats[:timings].max.round(2)}s"
      speed = total_processed > 0 ? (total_processed / (elapsed / 3600.0)).round(1) : 0
      info "  Speed:        #{speed} deals/hour"
    end
    
    info ""
    
    if @stats[:errors].any?
      info "ERRORS (#{@stats[:errors].count}):"
      
      # Group errors by type
      errors_by_type = @stats[:errors].group_by { |e| e[:error_class] }
      errors_by_type.each do |error_class, errors|
        info "  #{error_class}: #{errors.count} occurrences"
        errors.first(3).each_with_index do |err, idx|
          info "    [#{idx + 1}] Quote #{err[:quote_id]} - #{err[:error_message][0..100]}"
        end
        info "    ..." if errors.count > 3
      end
      info ""
    end
    
    info "="*100
    info "Full details available in CSV report file"
    info "="*100
  end
  
  def close
    @csv_file.close if @csv_file
  end
end

# =============================================================================
# SET ENVIRONMENT & LOAD RAILS
# =============================================================================

ENV['RAILS_ENV'] ||= 'production'
ENV['RUBY_DEBUG_SKIP'] = '1'

# Load Rails environment to access models
require_relative '../config/environment'

# =============================================================================
# MASTER SYNC ORCHESTRATOR
# =============================================================================

class MasterSyncV2
  def initialize(config, logger)
    @config = config
    @logger = logger
  end
  
  def run
    @logger.info "="*100
    @logger.info "MASTER FULL DATA SYNC V2 - START"
    @logger.info "="*100
    @logger.info "Configuration:", data: {
      csv_file: @config.csv_file,
      start_index: @config.start_index,
      end_index: @config.end_index || 'All',
      limit: @config.limit || 'All',
      dry_run: @config.dry_run,
      pipeline_filter: @config.pipeline_filter || 'All',
      handle_duplicates: @config.handle_duplicates,
      skip_line_items: @config.skip_line_items,
      skip_associations: @config.skip_associations
    }
    @logger.info "="*100
    @logger.info ""
    
    if @config.dry_run
      @logger.warn "🔍 DRY RUN MODE - No changes will be made"
      @logger.info ""
    end
    
    # Load deals from CSV
    deals = load_deals_from_csv
    
    # Sync deals
    sync_all_deals(deals)
    
    # Print summary
    @logger.print_summary
    @logger.close
  end
  
  private
  
  def load_deals_from_csv
    script_dir = File.dirname(File.expand_path(__FILE__))
    
    # Try multiple paths
    possible_paths = [
      File.join(script_dir, @config.csv_file),
      File.join(script_dir, '..', @config.csv_file),
      @config.csv_file
    ]
    
    csv_path = possible_paths.find { |path| File.exist?(path) }
    
    unless csv_path
      @logger.error "CSV file not found", data: { 
        csv_file: @config.csv_file, 
        tried_paths: possible_paths.join(', ') 
      }
      raise "CSV file not found: #{@config.csv_file}"
    end
    
    @logger.info "Loading CSV file:", data: { 
      path: csv_path, 
      size_mb: (File.size(csv_path) / 1024.0 / 1024.0).round(2) 
    }
    
    deals = []
    seen_quote_ids = {}
    
    CSV.foreach(csv_path, headers: true) do |row|
      quote_id = row['Simpro Quote Id']&.strip
      next if quote_id.nil? || quote_id.empty?
      
      deal = {
        record_id: row['Record ID']&.strip,
        deal_name: row['Deal Name']&.strip,
        simpro_quote_id: quote_id,
        amount: row['Amount']&.strip,
        pipeline: row['Pipeline']&.strip
      }
      
      # Handle duplicates
      if seen_quote_ids[quote_id]
        case @config.handle_duplicates
        when 'skip'
          @logger.debug "Skipping duplicate", data: { quote_id: quote_id }
          next
        when 'first'
          @logger.debug "Skipping duplicate (keeping first)", data: { quote_id: quote_id }
          next
        when 'all'
          deals << deal
        end
      else
        seen_quote_ids[quote_id] = true
        deals << deal
      end
    end
    
    @logger.info "✅ Loaded CSV successfully", data: { 
      total_deals: deals.count, 
      unique_quotes: seen_quote_ids.count 
    }
    
    deals
  end
  
  def sync_all_deals(deals)
    # Apply limits
    start_idx = @config.start_index || 0
    end_idx = @config.end_index || (deals.count - 1)
    limit = @config.limit || deals.count
    
    deals_to_sync = deals[start_idx..end_idx].first(limit)
    
    @logger.info "Starting sync:", data: {
      total_available: deals.count,
      range: "#{start_idx}-#{end_idx}",
      to_sync: deals_to_sync.count
    }
    @logger.info ""
    
    deals_to_sync.each_with_index do |deal, index|
      # Progress logging
      current = index + 1
      @logger.progress(current, deals_to_sync.count, data: {
        quote_id: deal[:simpro_quote_id],
        deal_id: deal[:record_id],
        deal_name: deal[:deal_name] || '[No Name]'
      })
      
      # Sync individual deal
      sync_start = Time.now
      sync_single_deal(deal)
      sync_duration = Time.now - sync_start
      
      @logger.add_timing(sync_duration)
      
      # Rate limiting
      sleep(0.5)
    end
    
    @logger.info ""
    @logger.info "✅ Sync process complete", data: { total_processed: deals_to_sync.count }
  end
  
  def sync_single_deal(deal)
    return if @config.dry_run
    
    deal_id = deal[:record_id]
    quote_id = deal[:simpro_quote_id]
    
    begin
      # Step 1: Validate deal exists and not archived
      deal_response = fetch_deal(deal_id)
      return unless deal_response
      
      # Step 2: Check pipeline filter
      if @config.pipeline_filter
        pipeline = deal_response['properties']['pipeline']
        unless pipeline == @config.pipeline_filter
          @logger.skip "Pipeline mismatch", data: {
            quote_id: quote_id,
            deal_id: deal_id,
            pipeline: pipeline,
            filter: @config.pipeline_filter,
            status: 'skipped_pipeline'
          }
          @logger.increment(:deals_skipped)
          return
        end
      end
      
      # Step 3: Skip archived duplicates
      if is_archived_duplicate?(deal_response)
        @logger.skip "Archived duplicate", data: {
          quote_id: quote_id,
          deal_id: deal_id,
          status: 'skipped_duplicate'
        }
        @logger.increment(:deals_skipped)
        return
      end
      
      # Step 4: Fetch full quote data from simPRO
      quote_data = fetch_quote_full(quote_id)
      return unless quote_data
      
      # Step 5: Fetch timeline data
      timeline_data = fetch_timeline(quote_id)
      
      # Step 6: Update deal properties and line items using existing models
      sync_result = perform_full_sync(quote_data, timeline_data, deal_id)
      
      if sync_result[:success]
        @logger.success "✅ Synced successfully", data: {
          quote_id: quote_id,
          deal_id: deal_id,
          deal_name: deal[:deal_name],
          duration: sync_result[:duration],
          line_items: sync_result[:line_items],
          associations: sync_result[:associations],
          status: 'success'
        }
        @logger.increment(:deals_synced)
        @logger.increment(:line_items_created, sync_result[:line_items] || 0)
        @logger.increment(:associations_created, sync_result[:associations] || 0)
      else
        @logger.error "Sync failed", data: {
          quote_id: quote_id,
          deal_id: deal_id,
          error_message: sync_result[:error],
          status: 'failed'
        }
        @logger.increment(:deals_failed)
      end
      
    rescue => e
      @logger.increment(:deals_failed)
      @logger.error "❌ Unexpected error", data: {
        quote_id: quote_id,
        deal_id: deal_id,
        error_class: e.class.name,
        error_message: e.message,
        status: 'error'
      }
      @logger.add_error(quote_id, e.class.name, e.message, deal_id: deal_id, backtrace: e.backtrace)
      @logger.debug "Backtrace:", data: { trace: e.backtrace.first(10).join("\n") }
    end
  end
  
  def fetch_deal(deal_id)
    response = HTTParty.get(
      "https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}",
      query: { properties: 'dealname,simpro_quote_id,dealstage,closed_lost_reason,pipeline' },
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      },
      timeout: 30
    )
    
    unless response.success?
      @logger.skip "Deal not found in HubSpot", data: {
        deal_id: deal_id,
        code: response.code,
        status: 'not_found'
      }
      @logger.increment(:deals_not_found)
      return nil
    end
    
    response.parsed_response
  end
  
  def is_archived_duplicate?(deal_response)
    return false unless deal_response['properties']
    
    deal_stage = deal_response['properties']['dealstage']
    closed_reason = deal_response['properties']['closed_lost_reason']
    
    deal_stage == 'closedlost' && closed_reason == 'Duplicate - Merged'
  end
  
  def fetch_quote_full(quote_id)
    response = HTTParty.get(
      "#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}?display=all",
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      },
      timeout: 30
    )
    
    unless response.success?
      if response.code == 404
        @logger.skip "Quote not found in simPRO", data: {
          quote_id: quote_id,
          code: 404,
          status: 'not_found'
        }
        @logger.increment(:deals_not_found)
      else
        @logger.error "Failed to fetch quote", data: {
          quote_id: quote_id,
          code: response.code,
          message: response.message,
          status: 'fetch_failed'
        }
        @logger.increment(:deals_failed)
      end
      return nil
    end
    
    response.parsed_response
  end
  
  def fetch_timeline(quote_id)
    response = HTTParty.get(
      "#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/timelines/",
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      },
      timeout: 30
    )
    
    response.success? ? response.parsed_response : nil
  rescue => e
    @logger.debug "Could not fetch timeline", data: { quote_id: quote_id, error: e.message }
    nil
  end
  
  def perform_full_sync(quote_data, timeline_data, deal_id)
    sync_start = Time.now
    line_items_count = 0
    associations_count = 0
    
    begin
      # Use existing Rails models for sync
      # This ensures we use the latest logic including cost-center-based discounts
      
      # Update deal properties (uses Hubspot::Deal.update_deal_value)
      Hubspot::Deal.update_deal_value(quote_data, timeline_data, deal_id)
      
      # Create/update site and contact associations unless skipped
      unless @config.skip_associations
        associations_count = create_associations(quote_data, deal_id)
      end
      
      # Note: Hubspot::Deal.update_deal_value already calls Hubspot::Quote.update_quote
      # which handles line items. Line items are created as part of that flow.
      # We can track the count by checking associations after sync.
      unless @config.skip_line_items
        line_items_count = count_line_items(deal_id)
      end
      
      sync_duration = (Time.now - sync_start).round(2)
      
      {
        success: true,
        duration: sync_duration,
        line_items: line_items_count,
        associations: associations_count
      }
      
    rescue => e
      {
        success: false,
        error: "#{e.class.name}: #{e.message}",
        duration: (Time.now - sync_start).round(2)
      }
    end
  end
  
  def create_associations(quote_data, deal_id)
    associations_created = 0
    
    begin
      # Create site association
      site_id = quote_data.dig('Site', 'ID')
      if site_id.present?
        if create_site_association(deal_id, site_id)
          associations_created += 1
        end
      end
      
      # Create contact/company association
      customer_id = quote_data.dig('Customer', 'ID')
      customer_type = quote_data.dig('Customer', 'Type')
      
      if customer_id.present?
        if customer_type == 'Company'
          if create_company_association(deal_id, customer_id)
            associations_created += 1
          end
        else
          if create_contact_association(deal_id, customer_id)
            associations_created += 1
          end
        end
      end
      
    rescue => e
      @logger.debug "Association creation error", data: {
        deal_id: deal_id,
        error: e.message
      }
    end
    
    associations_created
  end
  
  def create_site_association(deal_id, simpro_site_id)
    # Find HubSpot site by simPRO site ID
    site_search = HTTParty.post(
      'https://api.hubapi.com/crm/v3/objects/p_sites/search',
      body: {
        filterGroups: [{
          filters: [{
            propertyName: 'simpro_site_id',
            operator: 'EQ',
            value: simpro_site_id.to_s
          }]
        }]
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      },
      timeout: 10
    )
    
    return false unless site_search.success? && site_search['results'].present?
    
    site_id = site_search['results'].first['id']
    
    # Create association (type 109 = deal to site)
    response = HTTParty.put(
      "https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}/associations/p_sites/#{site_id}/109",
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      },
      timeout: 10
    )
    
    response.success?
  rescue => e
    @logger.debug "Site association failed", data: { deal_id: deal_id, site_id: simpro_site_id, error: e.message }
    false
  end
  
  def create_contact_association(deal_id, simpro_customer_id)
    # Find HubSpot contact by simPRO customer ID
    contact_search = HTTParty.post(
      'https://api.hubapi.com/crm/v3/objects/contacts/search',
      body: {
        filterGroups: [{
          filters: [{
            propertyName: 'simpro_customer_id',
            operator: 'EQ',
            value: simpro_customer_id.to_s
          }]
        }]
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      },
      timeout: 10
    )
    
    return false unless contact_search.success? && contact_search['results'].present?
    
    contact_id = contact_search['results'].first['id']
    
    # Create association
    response = HTTParty.put(
      "https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}/associations/contacts/#{contact_id}/deal_to_contact",
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      },
      timeout: 10
    )
    
    response.success?
  rescue => e
    @logger.debug "Contact association failed", data: { deal_id: deal_id, customer_id: simpro_customer_id, error: e.message }
    false
  end
  
  def create_company_association(deal_id, simpro_customer_id)
    # Find HubSpot company by simPRO customer ID
    company_search = HTTParty.post(
      'https://api.hubapi.com/crm/v3/objects/companies/search',
      body: {
        filterGroups: [{
          filters: [{
            propertyName: 'simpro_customer_id',
            operator: 'EQ',
            value: simpro_customer_id.to_s
          }]
        }]
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      },
      timeout: 10
    )
    
    return false unless company_search.success? && company_search['results'].present?
    
    company_id = company_search['results'].first['id']
    
    # Create association
    response = HTTParty.put(
      "https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}/associations/companies/#{company_id}/deal_to_company",
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      },
      timeout: 10
    )
    
    response.success?
  rescue => e
    @logger.debug "Company association failed", data: { deal_id: deal_id, customer_id: simpro_customer_id, error: e.message }
    false
  end
  
  def count_line_items(deal_id)
    response = HTTParty.get(
      "https://api.hubapi.com/crm/v4/objects/deals/#{deal_id}/associations/line_items",
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      },
      timeout: 10
    )
    
    return 0 unless response.success?
    
    response['results']&.count || 0
  rescue
    0
  end
end

# =============================================================================
# MAIN EXECUTION
# =============================================================================

if __FILE__ == $0
  # Parse configuration
  config = SyncConfig.new
  config.parse_args!
  
  # Initialize logger
  logger = StructuredLogger.new(verbose: config.verbose)
  
  # Check environment variables
  unless ENV['SIMPRO_TEST_URL'] && ENV['SIMPRO_TEST_KEY_ID'] && ENV['HUBSPOT_ACCESS_TOKEN']
    logger.error "❌ Missing required environment variables", data: {
      required: "SIMPRO_TEST_URL, SIMPRO_TEST_KEY_ID, HUBSPOT_ACCESS_TOKEN",
      found: "#{ENV['SIMPRO_TEST_URL'] ? 'SIMPRO_TEST_URL' : ''} #{ENV['SIMPRO_TEST_KEY_ID'] ? 'SIMPRO_TEST_KEY_ID' : ''} #{ENV['HUBSPOT_ACCESS_TOKEN'] ? 'HUBSPOT_ACCESS_TOKEN' : ''}".strip
    }
    exit 1
  end
  
  # Run sync
  sync = MasterSyncV2.new(config, logger)
  
  begin
    sync.run
  rescue Interrupt
    logger.warn "\n\n⚠️  Sync interrupted by user (Ctrl+C)"
    logger.print_summary
    exit 1
  rescue => e
    logger.error "\n\n❌ Fatal error: #{e.class.name}: #{e.message}"
    logger.error "Backtrace: #{e.backtrace.first(10).join("\n")}"
    logger.print_summary
    exit 1
  end
  
  logger.info "\n\n🎉 Sync completed successfully!"
  exit 0
end

