#!/usr/bin/env ruby

# Railway Bulk Line Item Sync Function
# Run with: ruby railway_sync_function.rb

require 'csv'
require 'httparty'
require 'json'
require 'logger'
require 'dotenv/load'

# Initialize environment
ENV['RAILS_ENV'] ||= 'production'
require_relative 'config/environment'

class RailwayLineItemSync
  VERSION = '1.0.0'
  
  def initialize
    @logger = setup_logger
    @stats = initialize_stats
    @start_time = Time.now
    
    log_info "=" * 100
    log_info "RAILWAY LINE ITEM SYNC v#{VERSION}"
    log_info "=" * 100
    log_info "Started at: #{@start_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    log_info "Environment: #{ENV['RAILS_ENV']}"
    log_info "=" * 100
  end
  
  def run(csv_file: 'hubspot-crm-exports-all-deals-2025-11-21.csv', limit: nil, start_from: 0)
    validate_environment
    
    deals = load_deals_from_csv(csv_file)
    log_info "Total deals in CSV: #{deals.count}"
    
    # Apply filters
    deals = deals.drop(start_from) if start_from > 0
    deals = deals.first(limit) if limit
    
    @stats[:total] = deals.count
    log_info "Syncing #{@stats[:total]} deals (starting from index #{start_from})"
    log_info "=" * 100
    
    # Process deals
    deals.each_with_index do |deal, index|
      actual_index = start_from + index
      process_deal(deal, actual_index, deals.count)
      
      # Progress report every 50 deals
      log_progress_report(actual_index + 1) if (actual_index + 1) % 50 == 0
      
      # Rate limiting
      sleep(0.3) if index < deals.count - 1
    end
    
    # Final summary
    generate_final_report(deals.count)
    
  rescue => e
    log_error "FATAL ERROR: #{e.class}: #{e.message}"
    log_error e.backtrace.join("\n")
    raise
  ensure
    @logger.close if @logger
  end
  
  private
  
  def setup_logger
    # Log to both file and stdout
    log_file = "railway_sync_#{Time.now.strftime('%Y%m%d_%H%M%S')}.log"
    
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity.ljust(5)} | #{msg}\n"
    end
    
    # Also write to file
    file_logger = Logger.new(log_file)
    file_logger.level = Logger::DEBUG
    file_logger.formatter = logger.formatter
    
    # Create a composite logger
    MultiLogger.new(logger, file_logger, log_file)
  end
  
  def initialize_stats
    {
      total: 0,
      successful: 0,
      failed: 0,
      skipped: 0,
      errors: [],
      timings: []
    }
  end
  
  def validate_environment
    required_vars = ['SIMPRO_TEST_URL', 'SIMPRO_TEST_KEY_ID', 'HUBSPOT_ACCESS_TOKEN']
    missing = required_vars.select { |var| ENV[var].nil? || ENV[var].empty? }
    
    if missing.any?
      raise "Missing required environment variables: #{missing.join(', ')}"
    end
    
    log_info "✓ Environment validated"
  end
  
  def load_deals_from_csv(csv_file)
    unless File.exist?(csv_file)
      raise "CSV file not found: #{csv_file}"
    end
    
    deals = []
    CSV.foreach(csv_file, headers: true) do |row|
      next if row['Simpro Quote Id'].nil? || row['Simpro Quote Id'].strip.empty?
      
      deals << {
        record_id: row['Record ID'],
        deal_name: row['Deal Name'],
        deal_stage: row['Deal Stage'],
        simpro_quote_id: row['Simpro Quote Id'].strip
      }
    end
    
    deals
  end
  
  def process_deal(deal, index, total)
    deal_start = Time.now
    
    log_info "[#{index + 1}/#{total}] Processing: #{deal[:deal_name]} (Quote: #{deal[:simpro_quote_id]})"
    
    # Fetch quote from Simpro
    quote_response = fetch_simpro_quote(deal[:simpro_quote_id])
    
    unless quote_response&.success?
      handle_quote_fetch_error(deal, quote_response)
      return
    end
    
    # Sync line items using optimized method
    sync_line_items(deal, quote_response)
    
    # Record success
    duration = Time.now - deal_start
    @stats[:timings] << duration
    @stats[:successful] += 1
    
    log_success "[#{index + 1}/#{total}] ✓ Completed in #{duration.round(2)}s"
    
  rescue => e
    @stats[:failed] += 1
    log_deal_error(deal, e, index, total)
    
    # Store error details
    @stats[:errors] << {
      index: index,
      deal_id: deal[:record_id],
      deal_name: deal[:deal_name],
      quote_id: deal[:simpro_quote_id],
      error_class: e.class.name,
      error_message: e.message,
      timestamp: Time.now.iso8601
    }
  end
  
  def fetch_simpro_quote(quote_id)
    HTTParty.get(
      "#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}?display=all",
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      },
      timeout: 30
    )
  rescue HTTParty::Error, Timeout::Error => e
    log_warn "Network error fetching quote #{quote_id}: #{e.message}"
    nil
  end
  
  def handle_quote_fetch_error(deal, response)
    if response.nil?
      log_warn "⚠ Skipped: Network timeout or connection error"
      @stats[:skipped] += 1
    elsif response.code == 404
      log_warn "⚠ Skipped: Quote #{deal[:simpro_quote_id]} not found in Simpro (404)"
      @stats[:skipped] += 1
    else
      raise "Simpro API error: #{response.code} - #{response.message}"
    end
  end
  
  def sync_line_items(deal, quote_response)
    existing_deal = {
      "results" => [{ "id" => deal[:record_id] }]
    }
    
    Hubspot::QuoteOptimized.create_line_item_optimized(
      deal[:simpro_quote_id],
      deal[:record_id],
      existing_deal
    )
  end
  
  def log_progress_report(count)
    elapsed = Time.now - @start_time
    avg_time = @stats[:timings].any? ? @stats[:timings].sum / @stats[:timings].count : 0
    remaining = @stats[:total] - count
    est_remaining = remaining * avg_time
    
    log_info "=" * 100
    log_info "PROGRESS: #{count}/#{@stats[:total]} deals | " \
             "Success: #{@stats[:successful]} | " \
             "Failed: #{@stats[:failed]} | " \
             "Skipped: #{@stats[:skipped]}"
    log_info "TIMING: Avg #{avg_time.round(2)}s/deal | " \
             "Elapsed: #{format_duration(elapsed)} | " \
             "ETA: #{format_duration(est_remaining)}"
    log_info "=" * 100
  end
  
  def generate_final_report(total_processed)
    duration = Time.now - @start_time
    avg_time = @stats[:timings].any? ? @stats[:timings].sum / @stats[:timings].count : 0
    success_rate = @stats[:successful].to_f / @stats[:total] * 100
    
    log_info ""
    log_info "=" * 100
    log_info "SYNC COMPLETE"
    log_info "=" * 100
    log_info ""
    log_info "📊 RESULTS:"
    log_info "  Total Processed: #{@stats[:total]}"
    log_info "  ✓ Successful: #{@stats[:successful]} (#{success_rate.round(1)}%)"
    log_info "  ✗ Failed: #{@stats[:failed]}"
    log_info "  ⚠ Skipped: #{@stats[:skipped]}"
    log_info ""
    log_info "⏱️  PERFORMANCE:"
    log_info "  Total Time: #{format_duration(duration)}"
    log_info "  Average: #{avg_time.round(2)}s per deal"
    log_info "  Fastest: #{@stats[:timings].min&.round(2) || 0}s"
    log_info "  Slowest: #{@stats[:timings].max&.round(2) || 0}s"
    log_info ""
    
    if @stats[:errors].any?
      log_error "❌ ERRORS (#{@stats[:errors].count}):"
      @stats[:errors].each do |error|
        log_error "  [#{error[:index] + 1}] #{error[:deal_name]} (Quote: #{error[:quote_id]})"
        log_error "      Error: #{error[:error_class]}: #{error[:error_message]}"
      end
      log_info ""
      log_info "Full error details available in log file: #{@logger.log_file}"
    else
      log_success "✓ NO ERRORS - All deals processed successfully!"
    end
    
    log_info "=" * 100
    log_info "Log file: #{@logger.log_file}"
    log_info "=" * 100
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
  
  def log_info(message)
    @logger.info(message)
  end
  
  def log_success(message)
    @logger.info("✓ #{message}")
  end
  
  def log_warn(message)
    @logger.warn(message)
  end
  
  def log_error(message)
    @logger.error(message)
  end
  
  def log_deal_error(deal, error, index, total)
    log_error "[#{index + 1}/#{total}] ✗ FAILED: #{deal[:deal_name]}"
    log_error "  Deal ID: #{deal[:record_id]}"
    log_error "  Quote ID: #{deal[:simpro_quote_id]}"
    log_error "  Error: #{error.class}: #{error.message}"
    @logger.debug(error.backtrace.join("\n"))
  end
end

# Multi-logger to write to both stdout and file
class MultiLogger
  attr_reader :log_file
  
  def initialize(stdout_logger, file_logger, log_file)
    @stdout_logger = stdout_logger
    @file_logger = file_logger
    @log_file = log_file
  end
  
  def info(message)
    @stdout_logger.info(message)
    @file_logger.info(message)
  end
  
  def warn(message)
    @stdout_logger.warn(message)
    @file_logger.warn(message)
  end
  
  def error(message)
    @stdout_logger.error(message)
    @file_logger.error(message)
  end
  
  def debug(message)
    @file_logger.debug(message)
  end
  
  def close
    @file_logger.close
  end
end

# Main execution
if __FILE__ == $0
  # Parse command line arguments
  options = {
    csv_file: ENV['CSV_FILE'] || 'hubspot-crm-exports-all-deals-2025-11-21.csv',
    limit: ENV['LIMIT']&.to_i,
    start_from: ENV['START_FROM']&.to_i || 0
  }
  
  puts "\n🚀 Starting Railway Line Item Sync..."
  puts "   CSV File: #{options[:csv_file]}"
  puts "   Limit: #{options[:limit] || 'ALL'}"
  puts "   Start From: #{options[:start_from]}"
  puts "\n"
  
  syncer = RailwayLineItemSync.new
  syncer.run(**options)
  
  exit 0
end

