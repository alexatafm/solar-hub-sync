require 'csv'
require 'httparty'
require 'dotenv/load'
require_relative 'config/environment'

class BulkLineItemSync
  attr_reader :stats
  
  def initialize
    @stats = {
      total: 0,
      successful: 0,
      failed: 0,
      skipped: 0,
      errors: [],
      timings: [],
      start_time: nil,
      end_time: nil
    }
  end
  
  def sync_deals(limit: 100)
    csv_file = 'hubspot-crm-exports-all-deals-2025-11-21.csv'
    
    puts "\n" + "="*100
    puts "BULK LINE ITEM SYNC - 100 DEALS TEST"
    puts "="*100
    
    # Read CSV and get deals with Simpro Quote IDs
    deals_with_quotes = []
    CSV.foreach(csv_file, headers: true) do |row|
      next if row['Simpro Quote Id'].nil? || row['Simpro Quote Id'].strip.empty?
      deals_with_quotes << {
        record_id: row['Record ID'],
        deal_name: row['Deal Name'],
        deal_stage: row['Deal Stage'],
        simpro_quote_id: row['Simpro Quote Id'].strip
      }
    end
    
    puts "Total deals with Simpro Quote IDs: #{deals_with_quotes.count}"
    puts "Syncing first #{limit} deals..."
    puts "="*100 + "\n"
    
    # Select deals to sync
    deals_to_sync = deals_with_quotes.first(limit)
    @stats[:total] = deals_to_sync.count
    @stats[:start_time] = Time.now
    
    # Sync each deal
    deals_to_sync.each_with_index do |deal, index|
      begin
        sync_single_deal(deal, index + 1, deals_to_sync.count)
      rescue => e
        handle_error(deal, e)
      end
      
      # Show progress every 10 deals
      if (index + 1) % 10 == 0
        show_progress_update(index + 1)
      end
      
      # Small delay to avoid rate limiting
      sleep(0.5) if index < deals_to_sync.count - 1
    end
    
    @stats[:end_time] = Time.now
    
    # Show final summary
    show_final_summary(deals_with_quotes.count)
  end
  
  private
  
  def sync_single_deal(deal, current, total)
    deal_id = deal[:record_id]
    quote_id = deal[:simpro_quote_id]
    
    print "\r[#{current}/#{total}] Syncing: #{deal[:deal_name][0..60]}..."
    
    deal_start = Time.now
    
    # Check if quote exists in Simpro
    quote_response = HTTParty.get(
      "#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}?display=all",
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      }
    )
    
    unless quote_response.success?
      if quote_response.code == 404
        @stats[:skipped] += 1
        log_warning(deal, "Quote #{quote_id} not found in Simpro (404)")
        return
      else
        raise "Simpro API error: #{quote_response.code} - #{quote_response.message}"
      end
    end
    
    # Create existing_deal structure
    existing_deal = {
      "results" => [{
        "id" => deal_id
      }]
    }
    
    # Use optimized sync method
    Hubspot::QuoteOptimized.create_line_item_optimized(quote_id, deal_id, existing_deal)
    
    deal_duration = Time.now - deal_start
    @stats[:timings] << deal_duration
    @stats[:successful] += 1
    
    print "\r[#{current}/#{total}] ✓ #{deal[:deal_name][0..50]}... (#{deal_duration.round(2)}s)\n"
    
  rescue => e
    @stats[:failed] += 1
    raise e
  end
  
  def handle_error(deal, error)
    error_details = {
      deal_id: deal[:record_id],
      deal_name: deal[:deal_name],
      quote_id: deal[:simpro_quote_id],
      error_class: error.class.name,
      error_message: error.message,
      backtrace: error.backtrace.first(3)
    }
    
    @stats[:errors] << error_details
    
    puts "\n✗ ERROR: #{deal[:deal_name]}"
    puts "  Quote ID: #{deal[:simpro_quote_id]}"
    puts "  Error: #{error.message}"
    puts ""
  end
  
  def log_warning(deal, message)
    puts "\n⚠ WARNING: #{deal[:deal_name]}"
    puts "  #{message}"
    puts ""
  end
  
  def show_progress_update(current)
    avg_time = @stats[:timings].sum / @stats[:timings].count
    elapsed = Time.now - @stats[:start_time]
    remaining_deals = @stats[:total] - current
    estimated_remaining = remaining_deals * avg_time
    
    puts "\n" + "-"*100
    puts "PROGRESS UPDATE - #{current}/#{@stats[:total]} deals processed"
    puts "-"*100
    puts "  Successful: #{@stats[:successful]}"
    puts "  Failed: #{@stats[:failed]}"
    puts "  Skipped: #{@stats[:skipped]}"
    puts "  Average time per deal: #{avg_time.round(2)}s"
    puts "  Elapsed time: #{format_duration(elapsed)}"
    puts "  Estimated remaining: #{format_duration(estimated_remaining)}"
    puts "-"*100 + "\n"
  end
  
  def show_final_summary(total_available_deals)
    duration = @stats[:end_time] - @stats[:start_time]
    avg_time = @stats[:timings].any? ? @stats[:timings].sum / @stats[:timings].count : 0
    
    puts "\n\n" + "="*100
    puts "SYNC COMPLETE!"
    puts "="*100
    
    puts "\n📊 RESULTS:"
    puts "  Total processed: #{@stats[:total]}"
    puts "  ✓ Successful: #{@stats[:successful]} (#{(@stats[:successful].to_f / @stats[:total] * 100).round(1)}%)"
    puts "  ✗ Failed: #{@stats[:failed]}"
    puts "  ⚠ Skipped: #{@stats[:skipped]}"
    
    puts "\n⏱️  PERFORMANCE:"
    puts "  Total time: #{format_duration(duration)}"
    puts "  Average per deal: #{avg_time.round(2)}s"
    puts "  Fastest: #{@stats[:timings].min.round(2)}s"
    puts "  Slowest: #{@stats[:timings].max.round(2)}s"
    
    if @stats[:successful] > 0
      success_rate = @stats[:successful].to_f / @stats[:total]
      remaining_deals = total_available_deals - @stats[:total]
      estimated_successful = (remaining_deals * success_rate).round
      estimated_time = remaining_deals * avg_time
      
      puts "\n🔮 PREDICTION FOR REMAINING #{remaining_deals} DEALS:"
      puts "  Expected successful syncs: #{estimated_successful}"
      puts "  Expected failures: #{(remaining_deals - estimated_successful).round}"
      puts "  Estimated time: #{format_duration(estimated_time)}"
      puts "  Total project time: #{format_duration(duration + estimated_time)}"
    end
    
    if @stats[:errors].any?
      puts "\n❌ ERRORS LOGGED (#{@stats[:errors].count}):"
      @stats[:errors].each_with_index do |error, index|
        puts "\n  Error #{index + 1}:"
        puts "    Deal: #{error[:deal_name]} (ID: #{error[:deal_id]})"
        puts "    Quote: #{error[:quote_id]}"
        puts "    Type: #{error[:error_class]}"
        puts "    Message: #{error[:error_message]}"
      end
      
      # Write errors to log file
      File.open("sync_errors_#{Time.now.strftime('%Y%m%d_%H%M%S')}.log", 'w') do |f|
        f.puts "Line Item Sync Errors - #{Time.now}"
        f.puts "="*100
        @stats[:errors].each_with_index do |error, index|
          f.puts "\nError #{index + 1}:"
          f.puts "  Deal ID: #{error[:deal_id]}"
          f.puts "  Deal Name: #{error[:deal_name]}"
          f.puts "  Quote ID: #{error[:quote_id]}"
          f.puts "  Error Class: #{error[:error_class]}"
          f.puts "  Error Message: #{error[:error_message]}"
          f.puts "  Backtrace:"
          error[:backtrace].each { |line| f.puts "    #{line}" }
        end
      end
      puts "\n  ℹ️  Full error details written to sync_errors_*.log"
    end
    
    puts "\n" + "="*100
    
    # Summary stats for copy/paste
    puts "\n📋 QUICK STATS:"
    puts "Total: #{@stats[:total]} | Success: #{@stats[:successful]} | Failed: #{@stats[:failed]} | Skipped: #{@stats[:skipped]}"
    puts "Time: #{format_duration(duration)} | Avg: #{avg_time.round(2)}s/deal"
    puts "Remaining: #{total_available_deals - @stats[:total]} deals (~#{format_duration((total_available_deals - @stats[:total]) * avg_time)})"
    puts "="*100 + "\n"
  end
  
  def format_duration(seconds)
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
end

# Run the sync
puts "\n⚠️  Starting bulk sync in 3 seconds..."
puts "Press Ctrl+C to cancel\n"
sleep(3)

syncer = BulkLineItemSync.new
syncer.sync_deals(limit: 100)

