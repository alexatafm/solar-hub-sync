#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# MASTER FULL DATA SYNC SCRIPT
# =============================================================================
# Purpose: One-time comprehensive sync of ALL data from SimPRO to HubSpot
# 
# Syncs:
#  - Contacts (Individual Customers)
#  - Companies (Company Customers)
#  - Sites
#  - Deals (Quotes)
#  - Line Items (Quote Items)
#
# Usage:
#   ruby master_full_sync.rb [OPTIONS]
#
# Options:
#   --quotes-only          Sync only quotes (skip customers/sites)
#   --start-page=N         Start from page N (default: 1)
#   --end-page=N           End at page N (default: all)
#   --page-size=N          Items per page (default: 50, max: 250)
#   --pipeline=PIPELINE    Filter by pipeline (default=Residential, 1012446696=Commercial, 1011198445=Service)
#   --dry-run              Preview actions without syncing
#   --verbose              Enable detailed logging
#
# Examples:
#   ruby master_full_sync.rb --start-page=1 --end-page=10 --verbose
#   ruby master_full_sync.rb --pipeline=default --verbose      # Residential only
#   ruby master_full_sync.rb --pipeline=1012446696 --verbose   # Commercial only
# =============================================================================

require 'httparty'
require 'json'
require 'logger'
require 'optparse'
require 'csv'

# =============================================================================
# CONFIGURATION
# =============================================================================

class SyncConfig
  attr_accessor :csv_file, :start_index, :end_index, :limit, :dry_run, :verbose, :pipeline_filter, :handle_duplicates
  
  def initialize
    @csv_file = 'hubspot-crm-exports-all-deals-2025-11-28.csv'
    @start_index = 0
    @end_index = nil  # nil = sync all
    @limit = nil  # nil = no limit
    @dry_run = false
    @verbose = false
    @pipeline_filter = nil  # nil = all pipelines, 'default' = residential only
    @handle_duplicates = 'first'  # 'first', 'all', 'skip'
  end
  
  def parse_args!
    OptionParser.new do |opts|
      opts.banner = "Usage: master_full_sync.rb [OPTIONS]"
      
      opts.on("--csv-file=FILE", String, "CSV file path (default: hubspot-crm-exports-all-deals-2025-11-28.csv)") do |f|
        @csv_file = f
      end
      
      opts.on("--start-index=N", Integer, "Start from index N (default: 0)") do |n|
        @start_index = n
      end
      
      opts.on("--end-index=N", Integer, "End at index N (default: all)") do |n|
        @end_index = n
      end
      
      opts.on("--limit=N", Integer, "Limit to N deals (default: all)") do |n|
        @limit = n
      end
      
      opts.on("--pipeline=PIPELINE", "Filter by pipeline (default, 1012446696, 1011198445)") do |p|
        @pipeline_filter = p
      end
      
      opts.on("--duplicates=MODE", String, "How to handle duplicate quote IDs: first, all, skip (default: first)") do |m|
        @handle_duplicates = m
      end
      
      opts.on("--dry-run", "Preview actions without syncing") do
        @dry_run = true
      end
      
      opts.on("--verbose", "Enable detailed logging") do
        @verbose = true
      end
      
      opts.on("-h", "--help", "Show this help message") do
        puts opts
        exit
      end
    end.parse!
  end
end

# =============================================================================
# LOGGING SETUP - Structured for Railway Observability
# =============================================================================

class SyncLogger
  def initialize(verbose: false)
    @verbose = verbose
    @logger = Logger.new(STDOUT)
    @logger.level = verbose ? Logger::DEBUG : Logger::INFO
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{msg}\n"
    end
    
    # Also log to file
    @file_logger = Logger.new("sync_#{Time.now.strftime('%Y%m%d_%H%M%S')}.log")
    @file_logger.level = Logger::DEBUG
    @file_logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] [#{severity}] #{msg}\n"
    end
    
    @stats = {
      deals_synced: 0,
      deals_failed: 0,
      deals_skipped: 0,
      deals_not_found: 0,
      timings: [],
      errors: [],
      start_time: Time.now
    }
  end
  
  def log(level, tag, message, data: {})
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    log_msg = "[#{timestamp}] [#{tag}] #{message}"
    
    if data.any?
      log_msg += " | " + data.map { |k, v| "#{k}=#{v}" }.join(" | ")
    end
    
    case level
    when :info
      @logger.info(log_msg)
      @file_logger.info(log_msg)
    when :warn
      @logger.warn(log_msg)
      @file_logger.warn(log_msg)
    when :error
      @logger.error(log_msg)
      @file_logger.error(log_msg)
    when :debug
      @logger.debug(log_msg) if @verbose
      @file_logger.debug(log_msg)
    end
  end
  
  def info(message, data: {})
    log(:info, "SYNC", message, data: data)
  end
  
  def success(message, data: {})
    log(:info, "SUCCESS", message, data: data)
  end
  
  def warn(message, data: {})
    log(:warn, "WARN", message, data: data)
  end
  
  def error(message, data: {})
    log(:error, "ERROR", message, data: data)
  end
  
  def skip(message, data: {})
    log(:info, "SKIP", message, data: data)
  end
  
  def progress(current, total, remaining, eta, data: {})
    percentage = ((current.to_f / total) * 100).round(1)
    log(:info, "PROGRESS", 
        "#{current}/#{total} (#{percentage}%) | #{remaining} remaining | ETA: #{format_duration(eta)}",
        data: data)
  end
  
  def debug(message, data: {})
    log(:debug, "DEBUG", message, data: data)
  end
  
  def increment(key)
    @stats[key] += 1
  end
  
  def add_timing(duration)
    @stats[:timings] << duration
  end
  
  def add_error(quote_id, error_class, error_message, backtrace: nil)
    @stats[:errors] << {
      quote_id: quote_id,
      error_class: error_class,
      error_message: error_message,
      timestamp: Time.now.iso8601,
      backtrace: backtrace
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
    elapsed = Time.now - @stats[:start_time]
    total_processed = @stats[:deals_synced] + @stats[:deals_failed] + @stats[:deals_skipped] + @stats[:deals_not_found]
    success_rate = total_processed > 0 ? (@stats[:deals_synced].to_f / total_processed * 100).round(1) : 0
    avg_time = @stats[:timings].any? ? @stats[:timings].sum / @stats[:timings].count : 0
    
    info ""
    info "="*80
    info "SYNC SUMMARY"
    info "="*80
    info ""
    info "RESULTS:"
    info "  Total Processed: #{total_processed}"
    info "  Successful: #{@stats[:deals_synced]} (#{success_rate}%)"
    info "  Failed: #{@stats[:deals_failed]}"
    info "  Skipped: #{@stats[:deals_skipped]}"
    info "  Not Found: #{@stats[:deals_not_found]}"
    info ""
    info "PERFORMANCE:"
    info "  Total Time: #{format_duration(elapsed)}"
    info "  Average: #{avg_time.round(2)}s per deal"
    if @stats[:timings].any?
      info "  Fastest: #{@stats[:timings].min.round(2)}s"
      info "  Slowest: #{@stats[:timings].max.round(2)}s"
      speed = total_processed > 0 ? (total_processed / (elapsed / 3600.0)).round(1) : 0
      info "  Speed: #{speed} deals/hour"
    end
    info ""
    
    if @stats[:errors].any?
      error ""
      error "ERRORS (#{@stats[:errors].count}):"
      @stats[:errors].each_with_index do |err, idx|
        error "  [#{idx + 1}] Quote #{err[:quote_id]}"
        error "      #{err[:error_class]}: #{err[:error_message]}"
      end
      info ""
    end
    
    info "="*80
  end
end

# =============================================================================
# API HELPERS
# =============================================================================

class SimProAPI
  def self.get(endpoint, query: {})
    url = "#{ENV['SIMPRO_TEST_URL']}#{endpoint}"
    
    response = HTTParty.get(url, {
      query: query,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      },
      timeout: 30
    })
    
    unless response.success?
      raise "SimPRO API Error: #{response.code} - #{response.body[0..200]}"
    end
    
    response.parsed_response
  rescue => e
    raise "SimPRO API Request Failed: #{e.message}"
  end
  
  def self.get_quotes(page:, page_size:)
    get('/quotes/', query: {
      'columns' => 'ID,Customer,Site,Description,Name,Status,Total,Totals,DateIssued',
      'page' => page,
      'pageSize' => page_size
    })
  end
  
  def self.get_quote_full(quote_id)
    get("/quotes/#{quote_id}", query: { 'display' => 'all' })
  end
  
  def self.get_customer_individual(customer_id)
    get("/customers/individuals/#{customer_id}", query: {
      'columns' => 'ID,GivenName,Title,FamilyName,Phone,AltPhone,Address,CustomerType,Email,CellPhone,Sites'
    })
  end
  
  def self.get_customer_company(customer_id)
    get("/customers/companies/#{customer_id}", query: {
      'columns' => 'ID,CompanyName,Phone,Address,BillingAddress,Email,EIN,Website,Sites'
    })
  end
  
  def self.get_site(site_id)
    get("/sites/#{site_id}", query: {
      'columns' => 'ID,Name,Address,Customers'
    })
  end
end

class HubSpotAPI
  def self.post(endpoint, body:)
    url = "https://api.hubapi.com#{endpoint}"
    
    response = HTTParty.post(url, {
      body: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      },
      timeout: 30
    })
    
    unless response.success?
      raise "HubSpot API Error: #{response.code} - #{response.body[0..200]}"
    end
    
    response.parsed_response
  rescue => e
    raise "HubSpot API Request Failed: #{e.message}"
  end
  
  def self.patch(endpoint, body:)
    url = "https://api.hubapi.com#{endpoint}"
    
    response = HTTParty.patch(url, {
      body: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      },
      timeout: 30
    })
    
    unless response.success?
      raise "HubSpot API Error: #{response.code} - #{response.body[0..200]}"
    end
    
    response.parsed_response
  rescue => e
    raise "HubSpot API Request Failed: #{e.message}"
  end
  
  def self.find_deal_by_quote_id(quote_id)
    post('/crm/v3/objects/deals/search', body: {
      filterGroups: [{
        filters: [{
          propertyName: 'simpro_quote_id',
          operator: 'EQ',
          value: quote_id.to_s
        }]
      }]
    })
  end
  
  def self.find_contact_by_customer_id(customer_id)
    post('/crm/v3/objects/contacts/search', body: {
      filterGroups: [{
        filters: [{
          propertyName: 'simpro_customer_id',
          operator: 'EQ',
          value: customer_id.to_s
        }]
      }]
    })
  end
  
  def self.find_company_by_customer_id(customer_id)
    post('/crm/v3/objects/companies/search', body: {
      filterGroups: [{
        filters: [{
          propertyName: 'simpro_customer_id',
          operator: 'EQ',
          value: customer_id.to_s
        }]
      }]
    })
  end
  
  def self.find_site_by_site_id(site_id)
    post('/crm/v3/objects/p_sites/search', body: {
      filterGroups: [{
        filters: [{
          propertyName: 'simpro_site_id',
          operator: 'EQ',
          value: site_id.to_s
        }]
      }]
    })
  end
end

# =============================================================================
# SYNC LOGIC - Use existing app models
# =============================================================================

# Set production environment before loading Rails
ENV['RAILS_ENV'] ||= 'production'
ENV['RUBY_DEBUG_SKIP'] = '1'

# Load Rails environment
require_relative '../config/environment'

# Verify CSV file exists immediately after Rails loads and store the path
csv_file = 'hubspot-crm-exports-all-deals-2025-11-28.csv'
script_dir = File.dirname(File.expand_path(__FILE__))
csv_path = File.join(script_dir, csv_file)
app_csv_path = File.join(Rails.root, 'one-time-sync', csv_file)

# Store the verified CSV path in an environment variable so load_deals_from_csv can use it
if File.exist?(csv_path)
  ENV['CSV_FILE_PATH'] = csv_path
  puts "[DEBUG] CSV found at: #{csv_path}"
elsif File.exist?(app_csv_path)
  ENV['CSV_FILE_PATH'] = app_csv_path
  puts "[DEBUG] CSV found at: #{app_csv_path}"
else
  puts "[DEBUG] CSV NOT FOUND!"
  puts "[DEBUG] Script dir: #{script_dir}"
  puts "[DEBUG] Rails root: #{Rails.root}"
  puts "[DEBUG] Current dir: #{Dir.pwd}"
  puts "[DEBUG] Script dir contents: #{Dir.entries(script_dir).select { |f| f.end_with?('.csv') }.inspect}"
  puts "[DEBUG] Rails root/one-time-sync exists: #{Dir.exist?(File.join(Rails.root, 'one-time-sync'))}"
  if Dir.exist?(File.join(Rails.root, 'one-time-sync'))
    puts "[DEBUG] Rails root/one-time-sync contents: #{Dir.entries(File.join(Rails.root, 'one-time-sync')).select { |f| f.end_with?('.csv') }.inspect}"
  end
end

class MasterSync
  def initialize(config, logger)
    @config = config
    @logger = logger
  end
  
  def run
    @logger.info "="*80
    @logger.info "MASTER FULL DATA SYNC - START"
    @logger.info "="*80
    @logger.info "Configuration", data: {
      csv_file: @config.csv_file,
      start_index: @config.start_index,
      end_index: @config.end_index || 'All',
      limit: @config.limit || 'All',
      dry_run: @config.dry_run,
      pipeline_filter: @config.pipeline_filter || 'All pipelines',
      handle_duplicates: @config.handle_duplicates
    }
    @logger.info "="*80
    @logger.info ""
    
    if @config.dry_run
      @logger.warn "DRY RUN MODE - No actual changes will be made"
      @logger.info ""
    end
    
    # Load deals from CSV
    deals = load_deals_from_csv
    
    # Sync deals
    sync_deals_from_csv(deals)
    
    # Print summary
    @logger.print_summary
  end
  
  private
  
  def load_deals_from_csv
    # First, try the path we verified exists at startup
    if ENV['CSV_FILE_PATH'] && File.exist?(ENV['CSV_FILE_PATH'])
      csv_path = ENV['CSV_FILE_PATH']
      @logger.info "Using verified CSV path from startup", data: { csv_path: csv_path }
    else
      # Use Rails.root for absolute path resolution - most reliable
      script_dir = File.dirname(File.expand_path(__FILE__))
      app_root = Rails.root.to_s
      
      # Try paths in order of likelihood - use absolute paths
      tried_paths = [
        File.join(script_dir, @config.csv_file),                  # Same dir as script (most likely)
        File.join(app_root, 'one-time-sync', @config.csv_file),   # Rails root/one-time-sync (absolute)
        File.join(app_root, @config.csv_file),                    # Rails root (absolute)
        File.join(Dir.pwd, 'one-time-sync', @config.csv_file),    # Current dir/one-time-sync
        File.join(Dir.pwd, @config.csv_file),                     # Current dir
        @config.csv_file,                                         # Direct path
      ]
      
      csv_path = tried_paths.find { |path| File.exist?(path) && File.file?(path) }
      
      unless csv_path
        # Comprehensive debugging
        debug_info = {
          csv_file: @config.csv_file,
          script_dir: script_dir,
          app_root: app_root,
          current_dir: Dir.pwd,
          tried_paths: tried_paths.map { |p| "#{p} (exists: #{File.exist?(p)})" }
        }
        
        begin
          debug_info[:script_dir_exists] = Dir.exist?(script_dir)
          debug_info[:script_dir_contents] = Dir.entries(script_dir).select { |f| f.end_with?('.csv') || File.directory?(File.join(script_dir, f)) } if Dir.exist?(script_dir)
          
          one_time_sync_path = File.join(app_root, 'one-time-sync')
          debug_info[:one_time_sync_dir] = one_time_sync_path
          debug_info[:one_time_sync_dir_exists] = Dir.exist?(one_time_sync_path)
          debug_info[:one_time_sync_contents] = Dir.entries(one_time_sync_path).select { |f| f.end_with?('.csv') } if Dir.exist?(one_time_sync_path)
          
          debug_info[:app_root_contents] = Dir.entries(app_root).select { |f| f == 'one-time-sync' || f.end_with?('.csv') } if Dir.exist?(app_root)
          debug_info[:current_dir_contents] = Dir.entries(Dir.pwd).select { |f| f == 'one-time-sync' || f.end_with?('.csv') } if Dir.exist?(Dir.pwd)
        rescue => e
          debug_info[:dir_listing_error] = e.message
          debug_info[:dir_listing_backtrace] = e.backtrace.first(3)
        end
        
        @logger.error "CSV file not found", data: debug_info
        raise "CSV file not found: #{@config.csv_file}\nTried paths:\n#{tried_paths.map { |p| "  - #{p} (#{File.exist?(p) ? 'EXISTS' : 'NOT FOUND'})" }.join("\n")}\n\nDebug info: #{debug_info.inspect}"
      end
    end  # Close the if/else block
    
    @logger.info "Found CSV file", data: { csv_path: csv_path, file_size: File.size(csv_path), absolute_path: File.expand_path(csv_path) }
    
    deals = []
    seen_quote_ids = {}
    
    CSV.foreach(csv_path, headers: true) do |row|
      quote_id = row['Simpro Quote Id']&.strip
      next if quote_id.nil? || quote_id.empty?
      
      deal_id = row['Record ID']&.strip
      
      # Skip archived deals (duplicates we just merged)
      # Batch check archived deals to avoid too many API calls
      # We'll check during sync_quote_from_deal instead for efficiency
      
      deal = {
        record_id: deal_id,
        deal_name: row['Deal Name']&.strip,
        simpro_quote_id: quote_id,
        amount: row['Amount']&.strip
      }
      
      # Handle duplicates based on config
      if seen_quote_ids[quote_id]
        case @config.handle_duplicates
        when 'skip'
          @logger.debug "Skipping duplicate quote ID", data: { quote_id: quote_id, record_id: deal[:record_id] }
          next
        when 'all'
          deals << deal
        when 'first'
          # Skip - already have first one
          @logger.debug "Skipping duplicate quote ID (keeping first)", data: { quote_id: quote_id, record_id: deal[:record_id] }
          next
        end
      else
        seen_quote_ids[quote_id] = true
        deals << deal
      end
    end
    
    @logger.info "Loaded deals from CSV", data: { 
      total: deals.count, 
      csv_file: @config.csv_file,
      csv_path: csv_path,
      duplicates_handled: @config.handle_duplicates
    }
    
    deals
  end
  
  def sync_deals_from_csv(deals)
    # Apply limits
    start_idx = @config.start_index || 0
    end_idx = @config.end_index || deals.count - 1
    limit = @config.limit || deals.count
    
    deals_to_sync = deals[start_idx..end_idx].first(limit)
    
    @logger.info "Syncing deals", data: { 
      total_available: deals.count,
      start_index: start_idx,
      end_index: end_idx,
      limit: limit,
      deals_to_sync: deals_to_sync.count
    }
    
    deals_to_sync.each_with_index do |deal, index|
      # Calculate progress
      stats = @logger.instance_variable_get(:@stats)
      completed = stats[:deals_synced] + stats[:deals_failed] + stats[:deals_skipped] + stats[:deals_not_found]
      current = completed + 1
      total = deals_to_sync.count
      
      timings = stats[:timings]
      avg_time = timings.any? ? timings.sum / timings.count : 3.0
      remaining = total - (index + 1)
      eta = remaining * avg_time
      
      @logger.progress(
        current,
        total,
        remaining,
        eta,
        data: { 
          quote_id: deal[:simpro_quote_id], 
          deal_id: deal[:record_id],
          deal_name: deal[:deal_name] || '[No Name]'
        }
      )
      
      sync_start = Time.now
      sync_quote_from_deal(deal)
      sync_duration = Time.now - sync_start
      
      @logger.add_timing(sync_duration) if sync_duration > 0
      
      # Rate limiting
      sleep(0.5)
    end
    
    @logger.info "Sync complete", data: { total_processed: deals_to_sync.count }
  end
  
  def sync_quote_from_deal(deal)
    return if @config.dry_run
    
    deal_id = deal[:record_id]
    quote_id = deal[:simpro_quote_id]
    
    begin
      # Check pipeline filter if specified
      if @config.pipeline_filter
        @logger.debug "Checking pipeline filter", data: { deal_id: deal_id, quote_id: quote_id }
        
        deal_response = HTTParty.get(
          "https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}",
          query: { properties: 'pipeline' },
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
          }
        )
        
        if deal_response.success? && deal_response['properties']
          pipeline = deal_response['properties']['pipeline']
          
          unless pipeline == @config.pipeline_filter
            @logger.skip "Pipeline filter mismatch", data: { 
              deal_id: deal_id,
              quote_id: quote_id, 
              pipeline: pipeline, 
              filter: @config.pipeline_filter 
            }
            @logger.increment(:deals_skipped)
            return
          end
        else
          @logger.skip "Deal not found (cannot check pipeline)", data: { deal_id: deal_id, quote_id: quote_id }
          @logger.increment(:deals_not_found)
          return
        end
      end
      
      # Verify deal exists and is not archived
      deal_response = HTTParty.get(
        "https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}",
        query: { properties: 'dealname,simpro_quote_id,dealstage,closed_lost_reason' },
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
        }
      )
      
      unless deal_response.success?
        @logger.skip "Deal not found in HubSpot", data: { deal_id: deal_id, quote_id: quote_id, code: deal_response.code }
        @logger.increment(:deals_not_found)
        return
      end
      
      # Skip archived duplicate deals
      if deal_response['properties']
        deal_stage = deal_response['properties']['dealstage']
        closed_reason = deal_response['properties']['closed_lost_reason']
        
        if deal_stage == 'closedlost' && closed_reason == 'Duplicate - Merged'
          @logger.skip "Skipping archived duplicate deal", data: { deal_id: deal_id, quote_id: quote_id }
          @logger.increment(:deals_skipped)
          return
        end
      end
      
      # Fetch quote with display=all
      quote_response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}?display=all", {
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        },
        timeout: 30
      })

      # Handle quote fetch errors gracefully
      unless quote_response.success?
        if quote_response.code == 404
          @logger.skip "Quote not found in SimPRO", data: { deal_id: deal_id, quote_id: quote_id, code: 404 }
          @logger.increment(:deals_not_found)
        else
          @logger.error "Failed to fetch quote from SimPRO", data: { 
            deal_id: deal_id,
            quote_id: quote_id, 
            code: quote_response.code,
            message: quote_response.message
          }
          @logger.increment(:deals_failed)
          @logger.add_error(quote_id, "HTTPError", "SimPRO API returned #{quote_response.code}")
        end
        return
      end

      # Fetch timeline data
      timeline_response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/timelines/", {
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        },
        timeout: 30
      })
      
      timeline_data = timeline_response.success? ? timeline_response.parsed_response : nil
      
      # Perform sync
      quote_data = quote_response.parsed_response
      Hubspot::Deal.update_deal_value(quote_data, timeline_data)
      
      @logger.increment(:deals_synced)
      @logger.success "Quote synced successfully", data: { deal_id: deal_id, quote_id: quote_id }
      
    rescue HTTParty::Error, Timeout::Error => e
      # Network/timeout errors - handled gracefully
      @logger.skip "Network error fetching quote", data: { 
        deal_id: deal_id,
        quote_id: quote_id, 
        error: e.class.name,
        message: e.message 
      }
      @logger.increment(:deals_skipped)
      
    rescue => e
      # Unexpected errors - log as actual errors
      @logger.increment(:deals_failed)
      @logger.error "Error syncing quote", data: { 
        deal_id: deal_id,
        quote_id: quote_id,
        error_class: e.class.name,
        error_message: e.message
      }
      @logger.add_error(quote_id, e.class.name, e.message, backtrace: e.backtrace)
      @logger.debug "Backtrace", data: { backtrace: e.backtrace.join("\n") }
    end
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
  logger = SyncLogger.new(verbose: config.verbose)
  
  # Check environment variables
  unless ENV['SIMPRO_TEST_URL'] && ENV['SIMPRO_TEST_KEY_ID'] && ENV['HUBSPOT_ACCESS_TOKEN']
    logger.error "Missing required environment variables", data: {
      required: "SIMPRO_TEST_URL, SIMPRO_TEST_KEY_ID, HUBSPOT_ACCESS_TOKEN"
    }
    exit 1
  end
  
  # Check CSV file exists
  unless File.exist?(config.csv_file)
    logger.error "CSV file not found", data: { csv_file: config.csv_file }
    exit 1
  end
  
  # Run sync
  sync = MasterSync.new(config, logger)
  
  begin
    sync.run
  rescue Interrupt
    logger.warn "\n\n⚠️  Sync interrupted by user"
    logger.print_summary
    exit 1
  rescue => e
    logger.error "\n\n❌ Fatal error: #{e.message}"
    logger.error e.backtrace.join("\n")
    logger.print_summary
    exit 1
  end
  
  logger.info "\n\n🎉 Sync completed successfully!"
  exit 0
end

