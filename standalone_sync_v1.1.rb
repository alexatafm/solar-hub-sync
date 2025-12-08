#!/usr/bin/env ruby

# Standalone Railway Line Item Sync - No Rails Required
# Docker container version for one-time use
# OPTIMIZED VERSION with parallel processing

require 'csv'
require 'httparty'
require 'json'
require 'logger'
require 'thread'

class StandaloneLineItemSync
  VERSION = '1.2.0-optimized'
  PARALLEL_WORKERS = 3  # Process 3 deals simultaneously
  
  def initialize
    @logger = setup_logger
    @stats = initialize_stats
    @start_time = Time.now
    @labour_rates_cache = nil  # Global cache
    @stats_mutex = Mutex.new   # Thread-safe stats
    
    log_info "=" * 100
    log_info "STANDALONE LINE ITEM SYNC v#{VERSION}"
    log_info "=" * 100
    log_info "Started at: #{@start_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    log_info "Parallel Workers: #{PARALLEL_WORKERS}"
    log_info "=" * 100
  end
  
  def run
    validate_environment
    
    csv_file = ENV['CSV_FILE'] || 'hubspot-crm-exports-all-deals-2025-11-21.csv'
    limit = ENV['LIMIT']&.to_i
    start_from = ENV['START_FROM']&.to_i || 0
    
    deals = load_deals_from_csv(csv_file)
    log_info "Total deals in CSV: #{deals.count}"
    
    # Apply filters
    deals = deals.drop(start_from) if start_from > 0
    deals = deals.first(limit) if limit
    
    @stats[:total] = deals.count
    log_info "Syncing #{@stats[:total]} deals (starting from index #{start_from})"
    log_info "=" * 100
    
    # Pre-fetch labour rates once (global cache)
    log_info "🔄 Pre-fetching labour rates cache..."
    @labour_rates_cache = fetch_labour_rates_cache
    log_info "✓ Labour rates cached (#{@labour_rates_cache.count} rates)"
    log_info "=" * 100
    
    # Process deals in parallel using Thread pool
    queue = Queue.new
    deals.each_with_index { |deal, idx| queue << [deal, start_from + idx] }
    
    threads = PARALLEL_WORKERS.times.map do
      Thread.new do
        while !queue.empty?
          begin
            deal_data = queue.pop(true) rescue nil
            break unless deal_data
            
            deal, actual_index = deal_data
            process_deal(deal, actual_index, deals.count, start_from)
          rescue => e
            log_error "Thread error: #{e.message}"
          end
        end
      end
    end
    
    threads.each(&:join)
    
    # Final summary
    generate_final_report(deals.count, start_from)
    
  rescue => e
    log_error "FATAL ERROR: #{e.class}: #{e.message}"
    log_error e.backtrace.join("\n")
    raise
  end
  
  private
  
  def setup_logger
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity.ljust(5)} | #{msg}\n"
    end
    logger
  end
  
  def initialize_stats
    {
      total: 0,
      successful: 0,
      failed: 0,
      skipped: 0,
      errors: [],
      timings: [],
      line_items_created: 0,
      deals_updated: 0
    }
  end
  
  def validate_environment
    required_vars = ['SIMPRO_URL', 'SIMPRO_API_KEY', 'HUBSPOT_TOKEN']
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
  
  def process_deal(deal, index, total, start_from)
    deal_start = Time.now
    
    # Calculate remaining (thread-safe)
    @stats_mutex.synchronize do
      completed = @stats[:successful] + @stats[:failed] + @stats[:skipped]
      remaining = total - completed
      
      # Estimate time
      avg_time = @stats[:timings].any? ? @stats[:timings].sum / @stats[:timings].count : 0
      eta = remaining * avg_time
      
      log_info "[#{completed + 1}/#{total}] [#{remaining} remaining] [ETA: #{format_duration(eta)}]"
      log_info "  Processing: Deal #{deal[:record_id]} | Quote #{deal[:simpro_quote_id]} | #{deal[:deal_name]}"
    end
    
    # Fetch quote from Simpro with display=all
    quote_response = fetch_simpro_quote(deal[:simpro_quote_id])
    
    unless quote_response&.success?
      handle_quote_fetch_error(deal, quote_response)
      return
    end
    
    # Sync line items and get summary
    summary = sync_line_items(deal, quote_response, deal_start)
    
    # Record success (thread-safe)
    duration = Time.now - deal_start
    @stats_mutex.synchronize do
      @stats[:timings] << duration
      @stats[:successful] += 1
      @stats[:line_items_created] += summary[:line_items_count]
      @stats[:deals_updated] += 1
    end
    
    # Success log with summary
    log_info "  ✓ Synced: #{summary[:line_items_count]} items | Amount: $#{summary[:deal_amount]} | Time: #{duration.round(2)}s"
    
    # Progress checkpoint every 50 deals
    @stats_mutex.synchronize do
      if @stats[:successful] % 50 == 0
        log_progress_report(@stats[:successful], start_from)
      end
    end
    
  rescue => e
    @stats_mutex.synchronize do
      @stats[:failed] += 1
      log_deal_error(deal, e, index, total)
      
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
  end
  
  def fetch_simpro_quote(quote_id)
    HTTParty.get(
      "#{ENV['SIMPRO_URL']}/quotes/#{quote_id}?display=all",
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_API_KEY']}"
      },
      timeout: 30
    )
  rescue HTTParty::Error, Timeout::Error => e
    log_warn "Network error fetching quote #{quote_id}: #{e.message}"
    nil
  end
  
  def handle_quote_fetch_error(deal, response)
    @stats_mutex.synchronize do
      if response.nil?
        log_warn "  ⚠ Skipped: Network timeout or connection error"
        @stats[:skipped] += 1
      elsif response.code == 404
        log_warn "  ⚠ Skipped: Quote #{deal[:simpro_quote_id]} not found in Simpro (404)"
        @stats[:skipped] += 1
      else
        raise "Simpro API error: #{response.code} - #{response.message}"
      end
    end
  end
  
  def sync_line_items(deal, quote_response, deal_start_time)
    deal_id = deal[:record_id]
    quote = quote_response.parsed_response
    
    # Step 1: Delete existing line items (optimized - only if they exist)
    deleted = delete_existing_line_items(deal_id)
    
    # Step 2: Use global labour rates cache (no API call needed!)
    
    # Step 3: Process quote sections and build line items
    line_items = []
    
    if quote["Sections"] && quote["Sections"].any?
      quote["Sections"].each do |section|
        section["CostCenters"]&.each do |cost_center|
          line_items.concat(process_cost_center(cost_center, section["Name"], @labour_rates_cache))
        end
      end
    end
    
    # Step 4: Batch create line items in HubSpot
    if line_items.any?
      create_line_items_in_hubspot(line_items, deal_id)
    end
    
    # Step 5: Update deal properties from quote
    sync_duration = Time.now - deal_start_time
    update_deal_properties(deal_id, quote, sync_duration)
    
    # Step 6: Update Simpro with deal ID
    update_simpro_deal_id(deal_id, deal[:simpro_quote_id], quote)
    
    # Return summary for logging
    {
      line_items_count: line_items.count,
      deal_amount: (quote["Total"]["ExTax"].round(2) rescue 0)
    }
  end
  
  def delete_existing_line_items(deal_id)
    response = HTTParty.get(
      "https://api.hubapi.com/crm/v4/objects/deals/#{deal_id}/associations/line_items",
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['HUBSPOT_TOKEN']}"
      }
    )
    
    # Optimized: Only delete if items exist
    if response.success? && response["results"]&.any?
      delete_json = { "ids" => response["results"].map { |i| i["toObjectId"] } }
      
      HTTParty.post(
        "https://api.hubapi.com/crm-objects/v1/objects/line_items/batch-delete",
        body: delete_json.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{ENV['HUBSPOT_TOKEN']}"
        }
      )
      return response["results"].count
    end
    
    return 0
  end
  
  def fetch_labour_rates_cache
    response = HTTParty.get(
      "#{ENV['SIMPRO_URL']}/setup/labor/laborRates/",
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_API_KEY']}"
      }
    )
    
    cache = {}
    if response.success? && response.parsed_response && response.parsed_response.any?
      response.parsed_response.each do |rate|
        cache[rate["Name"]] = {
          id: rate["ID"],
          markup: (rate["Markup"]&.round(4) rescue 0),
          cost_rate: (rate["CostRate"]&.round(2) rescue 0)
        }
      end
    end
    cache
  end
  
  def process_cost_center(cost_center, section_name, labour_rates_cache)
    line_items = []
    
    cost_center_name = cost_center["CostCenter"]["Name"] rescue cost_center["Name"]
    cost_center_description = cost_center["Description"] rescue ""
    
    # Fix: Use OptionalDepartment instead of Billable for display=all
    is_optional_department = cost_center["OptionalDepartment"] == true
    primary_optional = is_optional_department ? "Optional" : "Primary"
    
    items = cost_center["Items"]
    return line_items unless items && items.any?
    
    # Process all item types
    line_items.concat(process_items(items["Catalogs"], "Catalogue", "Catalog", section_name, cost_center_name, cost_center_description, primary_optional, labour_rates_cache))
    line_items.concat(process_items(items["OneOffs"], "One-Off", "OneOff", section_name, cost_center_name, cost_center_description, primary_optional, labour_rates_cache))
    line_items.concat(process_items(items["Prebuilds"], "Pre-Builds", "Prebuild", section_name, cost_center_name, cost_center_description, primary_optional, labour_rates_cache))
    line_items.concat(process_items(items["ServiceFees"], "Service", "ServiceFee", section_name, cost_center_name, cost_center_description, primary_optional, labour_rates_cache))
    line_items.concat(process_items(items["Labors"], "Labour", "LaborType", section_name, cost_center_name, cost_center_description, primary_optional, labour_rates_cache))
    
    line_items
  end
  
  def process_items(items, type, key, section_name, cost_center_name, cost_center_description, primary_optional, labour_rates_cache)
    return [] unless items&.any?
    
    items.map do |item|
      # Skip negative prices and rebates
      amount = item["SellPrice"]["ExTax"].round(2) rescue 0
      
      if type == "Pre-Builds"
        prebuild_type = item["Prebuild"]["Type"] rescue nil
        next if (amount < 0) || (prebuild_type == "Rebates")
      else
        next if amount < 0
      end
      
      build_line_item(item, type, key, section_name, cost_center_name, cost_center_description, primary_optional, labour_rates_cache)
    end.compact
  end
  
  def build_line_item(item, type, key, section_name, cost_center_name, cost_center_description, primary_optional, labour_rates_cache)
    # Extract name and SKU based on type
    case key
    when "Catalog"
      product_name = item["Catalog"]["Name"]
      part_no = (item["Catalog"]["PartNo"] && !item["Catalog"]["PartNo"].to_s.empty?) ? item["Catalog"]["PartNo"] : item["ID"].to_s
      base_price = item["BasePrice"]
      markup = item["Markup"].to_f / 100 rescue 0
    when "OneOff"
      product_name = item["Description"]
      part_no = (item["PartNo"] && !item["PartNo"].to_s.empty?) ? item["PartNo"] : item["ID"].to_s
      base_price = item["BasePrice"]
      markup = item["Markup"].to_f / 100 rescue 0
    when "Prebuild"
      product_name = item["Prebuild"]["Name"]
      part_no = (item["Prebuild"]["PartNo"] && !item["Prebuild"]["PartNo"].to_s.empty?) ? item["Prebuild"]["PartNo"] : item["ID"].to_s
      base_price = item["BasePrice"]
      markup = item["Markup"].to_f / 100 rescue 0
    when "ServiceFee"
      product_name = item["ServiceFee"]["Name"]
      part_no = (item["ServiceFee"]["PartNo"] && !item["ServiceFee"]["PartNo"].to_s.empty?) ? item["ServiceFee"]["PartNo"] : item["ID"].to_s
      base_price = item["BasePrice"]
      markup = item["Markup"].to_f / 100 rescue 0
    when "LaborType"
      product_name = item["LaborType"]["Name"]
      part_no = (item["LaborType"]["PartNo"] && !item["LaborType"]["PartNo"].to_s.empty?) ? item["LaborType"]["PartNo"] : item["ID"].to_s
      
      if labour_rates_cache && labour_rates_cache[product_name]
        markup = labour_rates_cache[product_name][:markup]
        base_price = labour_rates_cache[product_name][:cost_rate]
      else
        markup = 0
        base_price = 0
      end
    end
    
    # Common fields
    amount = item["SellPrice"]["ExTax"].round(2) rescue 0
    quantity = item["Total"]["Qty"].round(2) rescue 0
    discount = item["Discount"].to_f rescue 0
    line_total_ex_tax = item["Total"]["Amount"]["ExTax"].round(2) rescue 0
    line_total_inc_tax = item["Total"]["Amount"]["IncTax"].round(2) rescue 0
    original_price = item["SellPrice"]["ExDiscountExTax"].round(2) rescue amount
    simpro_id = item["ID"].to_s rescue nil
    billable_status = item["BillableStatus"] || (primary_optional == "Primary" ? "Billable" : "Non-Billable")
    
    # Build properties array for HubSpot
    [
      { "name" => "quantity", "value" => quantity },
      { "name" => "name", "value" => product_name },
      { "name" => "price", "value" => amount },
      { "name" => "costcenter", "value" => cost_center_name },
      { "name" => "primary_optional_cost_centre", "value" => primary_optional },
      { "name" => "section", "value" => section_name },
      { "name" => "costcenter_description", "value" => cost_center_description },
      { "name" => "type", "value" => type },
      { "name" => "markup__", "value" => markup },
      { "name" => "cost_price", "value" => base_price },
      { "name" => "hs_sku", "value" => part_no },
      { "name" => "item_discount", "value" => discount },
      { "name" => "line_total__ex_tax_", "value" => line_total_ex_tax },
      { "name" => "line_total__inc_tax_", "value" => line_total_inc_tax },
      { "name" => "original_price_before_discount", "value" => original_price },
      { "name" => "simpro_catalogue_id", "value" => simpro_id },
      { "name" => "billable_status", "value" => billable_status }
    ]
  end
  
  def create_line_items_in_hubspot(line_items, deal_id)
    response = HTTParty.post(
      "https://api.hubapi.com/crm-objects/v1/objects/line_items/batch-create",
      body: line_items.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['HUBSPOT_TOKEN']}"
      }
    )
    
    if response.success?
      line_item_ids = response.map { |i| i["properties"]["hs_object_id"] }.map { |i| i["value"] }
      
      # Associate with deal
      asso_body = {
        inputs: line_item_ids.map do |to_id|
          { "from" => { "id" => deal_id }, "to" => { "id" => to_id }, "type" => "deal_to_line_item" }
        end
      }
      
      HTTParty.post(
        "https://api.hubapi.com/crm/v3/associations/deal/line_item/batch/create",
        body: asso_body.to_json,
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['HUBSPOT_TOKEN']}"
        }
      )
    else
      raise "Error creating line items: #{response.code} - #{response.body[0..500]}"
    end
  end
  
  def update_deal_properties(deal_id, quote, sync_duration)
    body_json = {
      "properties" => {
        "amount" => (quote["Total"]["ExTax"] rescue 0),
        "last_synced" => (Time.now.to_i * 1000),
        "sync_time" => "#{sync_duration.round(2)} seconds"
      }
    }
    
    HTTParty.patch(
      "https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}/",
      body: body_json.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['HUBSPOT_TOKEN']}"
      }
    )
  end
  
  def update_simpro_deal_id(deal_id, quote_id, quote)
    # Check if deal ID already set
    hs_value = quote["CustomFields"]&.find { |cf| cf["CustomField"]["ID"] == 229 }&.dig("Value")
    
    return if hs_value && !hs_value.to_s.empty?
    
    # Update Simpro with HubSpot deal ID
    body_json = { "Value" => deal_id }
    
    HTTParty.patch(
      "#{ENV['SIMPRO_URL']}/quotes/#{quote_id}/customFields/229",
      body: body_json.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_API_KEY']}"
      }
    )
  end
  
  def log_progress_report(count, start_from)
    elapsed = Time.now - @start_time
    completed = count - start_from
    avg_time = @stats[:timings].any? ? @stats[:timings].sum / @stats[:timings].count : 0
    remaining = @stats[:total] - completed
    est_remaining = remaining * avg_time
    
    log_info "=" * 100
    log_info "CHECKPOINT: #{completed}/#{@stats[:total]} deals completed"
    log_info "  Success: #{@stats[:successful]} | Failed: #{@stats[:failed]} | Skipped: #{@stats[:skipped]}"
    log_info "  Line Items Created: #{@stats[:line_items_created]} | Deals Updated: #{@stats[:deals_updated]}"
    log_info "  Avg Time: #{avg_time.round(2)}s/deal | Elapsed: #{format_duration(elapsed)} | Remaining: #{format_duration(est_remaining)}"
    log_info "  Speed: #{(completed / elapsed * 60).round(1)} deals/min"
    log_info "=" * 100
  end
  
  def generate_final_report(total_processed, start_from)
    duration = Time.now - @start_time
    completed = total_processed
    avg_time = @stats[:timings].any? ? @stats[:timings].sum / @stats[:timings].count : 0
    success_rate = @stats[:successful].to_f / @stats[:total] * 100
    deals_per_hour = (@stats[:successful] / (duration / 3600.0)).round(1)
    
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
    log_info "📝 SYNC DETAILS:"
    log_info "  Line Items Created: #{@stats[:line_items_created]}"
    log_info "  Deals Updated: #{@stats[:deals_updated]}"
    log_info ""
    log_info "⏱️  PERFORMANCE:"
    log_info "  Total Time: #{format_duration(duration)}"
    log_info "  Average: #{avg_time.round(2)}s per deal"
    log_info "  Speed: #{deals_per_hour} deals/hour"
    log_info "  Fastest: #{@stats[:timings].min&.round(2) || 0}s"
    log_info "  Slowest: #{@stats[:timings].max&.round(2) || 0}s"
    log_info ""
    
    if @stats[:errors].any?
      log_error "❌ ERRORS (#{@stats[:errors].count}):"
      @stats[:errors].first(10).each do |error|
        log_error "  [#{error[:index] + 1}] #{error[:deal_name]} (Deal: #{error[:deal_id]}, Quote: #{error[:quote_id]})"
        log_error "      Error: #{error[:error_class]}: #{error[:error_message]}"
      end
      log_error "  ... and #{@stats[:errors].count - 10} more errors" if @stats[:errors].count > 10
    else
      log_info "✓ NO ERRORS - All deals processed successfully!"
    end
    
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
    @stats_mutex.synchronize { @logger.info(message) }
  end
  
  def log_warn(message)
    @stats_mutex.synchronize { @logger.warn(message) }
  end
  
  def log_error(message)
    @stats_mutex.synchronize { @logger.error(message) }
  end
  
  def log_deal_error(deal, error, index, total)
    log_error "  ✗ FAILED: #{deal[:deal_name]}"
    log_error "    Deal ID: #{deal[:record_id]}"
    log_error "    Quote ID: #{deal[:simpro_quote_id]}"
    log_error "    Error: #{error.class}: #{error.message}"
  end
end

# Main execution
if __FILE__ == $0
  puts "\n🚀 Starting Standalone Line Item Sync (OPTIMIZED)..."
  puts "   Version: 1.2.0"
  puts "   Parallel Workers: 3"
  puts "   Limit: #{ENV['LIMIT'] || 'ALL'}"
  puts "   Start From: #{ENV['START_FROM'] || 0}"
  puts "\n"
  
  syncer = StandaloneLineItemSync.new
  syncer.run
  
  exit 0
end
