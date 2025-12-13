#!/usr/bin/env ruby

require 'httparty'
require 'json'
require 'csv'
require 'logger'
require 'time'

# Load .env file if it exists (for local development)
begin
  require 'dotenv'
  Dotenv.load if File.exist?('.env')
rescue LoadError
  # dotenv not available, using environment variables directly
end

class JobsSync
  # HubSpot Pipeline Stage Mapping
  PIPELINE_STAGES = {
    "Quote Accepted" => "1654704594",
    "New Job - Awaiting Review" => "1654704595",
    "New Job - Awaiting Approval" => "1654704596",
    "New Job - Ready to schedule" => "1654704597",
    "Job Scheduled" => "1654704598",
    "Works Complete" => "1654704600",
    "Job Finished" => "1654704601",
    "On Hold" => "1654704602",
    "Site Visit Required" => "1654704602",
    "New Build" => "1654704602",
    "Warranty" => "1823035851",
    "Warranty - Parts Received" => "1823035851",
    "Warranty - Works Completed" => "1823035851",
    "Warranty - New Job" => "1823035851",
    "Job Cancelled" => "1654704603"
  }.freeze

  def initialize
    @simpro_url = ENV['SIMPRO_API_URL']
    @simpro_key = ENV['SIMPRO_API_KEY']
    @hubspot_token = ENV['HUBSPOT_ACCESS_TOKEN']
    @pipeline_id = ENV['HUBSPOT_JOB_PIPELINE_ID']
    
    @rate_limit_simpro = ENV.fetch('RATE_LIMIT_SIMPRO', 2).to_i
    @rate_limit_hubspot = ENV.fetch('RATE_LIMIT_HUBSPOT', 10).to_i
    @max_retries = ENV.fetch('MAX_RETRIES', 3).to_i
    @retry_delay = ENV.fetch('RETRY_DELAY', 5).to_i
    
    # Log to STDOUT for Railway/Docker console
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{msg}\n"
    end
    
    @stats = {
      total_jobs: 0,
      created: 0,
      updated: 0,
      skipped: 0,
      failed: 0,
      errors: []
    }
    
    @report_file = "jobs_sync_report_#{Time.now.strftime('%Y%m%d_%H%M%S')}.csv"
    initialize_report
    
    @last_simpro_request = Time.now
    @last_hubspot_request = Time.now
  end

  def run
    @logger.info "=" * 80
    @logger.info "Starting Jobs Sync"
    @logger.info "=" * 80
    @logger.info "Simpro URL: #{@simpro_url}"
    @logger.info "HubSpot Pipeline: #{@pipeline_id}"
    @logger.info ""
    
    start_time = Time.now
    
    begin
      jobs = fetch_all_jobs_from_simpro
      @logger.info "Fetched #{jobs.count} jobs from Simpro"
      @stats[:total_jobs] = jobs.count
      
      jobs.each_with_index do |job, index|
        @logger.info "Processing job #{index + 1}/#{jobs.count}: #{job['ID']} - #{job['Name']}"
        process_job(job)
      end
      
      end_time = Time.now
      duration = (end_time - start_time).round(2)
      
      print_summary(duration)
      
    rescue => e
      @logger.error "Fatal error: #{e.message}"
      @logger.error e.backtrace.join("\n")
      @stats[:errors] << { job_id: 'N/A', error: e.message, backtrace: e.backtrace.first(3) }
    end
  end

  private

  def fetch_all_jobs_from_simpro
    all_jobs = []
    page = 0
    page_size = 250
    
    loop do
      rate_limit_simpro
      
      @logger.info "Fetching page #{page + 1} from Simpro..."
      
      response = with_retry do
        HTTParty.get(
          "#{@simpro_url}/jobs/",
          query: { page: page, pageSize: page_size },
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{@simpro_key}"
          },
          timeout: 60
        )
      end
      
      if response.success?
        jobs = response.parsed_response
        break if jobs.nil? || jobs.empty?
        
        all_jobs.concat(jobs)
        @logger.info "Fetched #{jobs.count} jobs (total: #{all_jobs.count})"
        
        break if jobs.count < page_size
        page += 1
      else
        @logger.error "Failed to fetch jobs: #{response.code} - #{response.body}"
        break
      end
    end
    
    all_jobs
  end

  def process_job(job_summary)
    simpro_job_id = job_summary['ID']
    
    begin
      # Fetch full job details
      rate_limit_simpro
      job_details = fetch_job_details(simpro_job_id)
      
      unless job_details
        @logger.warn "Skipping job #{simpro_job_id}: Could not fetch details"
        @stats[:skipped] += 1
        write_report_row(simpro_job_id, job_summary['Name'], 'skipped', 'Could not fetch details')
        return
      end
      
      # Extract and map fields
      job_data = extract_job_fields(job_details)
      
      # Check if job already exists in HubSpot
      existing_hubspot_id = job_data[:hubspot_job_id]
      
      if present?(existing_hubspot_id)
        # Try to update existing job
        rate_limit_hubspot
        result = update_hubspot_job(existing_hubspot_id, job_data)
        
        if result == :not_found
          # Job was deleted from HubSpot, create a new one
          @logger.warn "Job #{existing_hubspot_id} not found in HubSpot (deleted). Creating new job..."
          rate_limit_hubspot
          hubspot_id = create_hubspot_job(job_data)
          
          if hubspot_id
            @stats[:created] += 1
            @logger.info "✅ Created replacement HubSpot job #{hubspot_id}"
            write_report_row(simpro_job_id, job_data[:job_name], 'created', hubspot_id)
            update_simpro_custom_field(simpro_job_id, hubspot_id)
            # Associate with contacts and sites
            associate_job_with_related_records(hubspot_id, job_details)
          else
            @stats[:failed] += 1
            @logger.error "❌ Failed to create replacement HubSpot job"
            write_report_row(simpro_job_id, job_data[:job_name], 'failed', 'Create failed after 404')
          end
        elsif result == true
          @stats[:updated] += 1
          @logger.info "✅ Updated HubSpot job #{existing_hubspot_id}"
          write_report_row(simpro_job_id, job_data[:job_name], 'updated', existing_hubspot_id)
          # Associate with contacts and sites
          associate_job_with_related_records(existing_hubspot_id, job_details)
        else
          @stats[:failed] += 1
          @logger.error "❌ Failed to update HubSpot job #{existing_hubspot_id}"
          write_report_row(simpro_job_id, job_data[:job_name], 'failed', 'Update failed')
        end
      else
        # Create new job
        rate_limit_hubspot
        hubspot_id = create_hubspot_job(job_data)
        
        if hubspot_id
          @stats[:created] += 1
          @logger.info "✅ Created HubSpot job #{hubspot_id}"
          write_report_row(simpro_job_id, job_data[:job_name], 'created', hubspot_id)
          
          # Update Simpro with HubSpot ID
          update_simpro_custom_field(simpro_job_id, hubspot_id)
          
          # Associate with contacts and sites
          associate_job_with_related_records(hubspot_id, job_details)
        else
          @stats[:failed] += 1
          @logger.error "❌ Failed to create HubSpot job"
          write_report_row(simpro_job_id, job_data[:job_name], 'failed', 'Create failed')
        end
      end
      
    rescue => e
      @stats[:failed] += 1
      @logger.error "Error processing job #{simpro_job_id}: #{e.message}"
      @logger.error e.backtrace.first(3).join("\n")
      @stats[:errors] << { job_id: simpro_job_id, error: e.message }
      write_report_row(simpro_job_id, job_summary['Name'], 'error', e.message)
    end
  end

  def fetch_job_details(job_id)
    response = with_retry do
      HTTParty.get(
        "#{@simpro_url}/jobs/#{job_id}",
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@simpro_key}"
        },
        timeout: 30
      )
    end
    
    response.success? ? response.parsed_response : nil
  end

  # Helper method to check if value is present (replaces Rails' .present?)
  def present?(value)
    !value.nil? && (value.is_a?(String) ? !value.strip.empty? : (value.respond_to?(:empty?) ? !value.empty? : true))
  end

  def extract_job_fields(job_response)
    data = {}
    
    # Find HubSpot job ID from custom field 262
    if present?(job_response["CustomFields"])
      hubspot_field = job_response["CustomFields"].find { |cf| cf["CustomField"]["ID"] == 262 }
      data[:hubspot_job_id] = hubspot_field["Value"] rescue nil if hubspot_field
    end

    # Category 1: Basic Job Information
    job_name = job_response["Name"] rescue nil
    data[:stage] = job_response["Stage"] rescue nil
    data[:job_status] = job_response["Status"]["Name"] rescue nil
    data[:simpro_job_id] = job_response["ID"] rescue nil
    
    # Extract site info early (needed for job name fallback)
    data[:site] = job_response["Site"]["Name"] rescue nil
    data[:site_id] = job_response["Site"]["ID"] rescue nil
    
    # Create job name in format: [Job ID] - "Job Name" (or Site Name as fallback)
    # Priority: 1) Job Name, 2) Site Name, 3) "Unnamed"
    if present?(job_name)
      # Use Job Name: [Job ID] - "Job Name"
      data[:job_name] = "[#{data[:simpro_job_id]}] - #{job_name}"
    elsif present?(data[:site])
      # Fallback to Site Name: [Job ID] - Site Name
      data[:job_name] = "[#{data[:simpro_job_id]}] - #{data[:site]}"
    else
      # Last resort: [Job ID] - Unnamed
      data[:job_name] = "[#{data[:simpro_job_id]}] - Unnamed"
    end
    
    # Map status to HubSpot pipeline stage
    data[:pipeline_stage] = PIPELINE_STAGES[data[:job_status]]
    
    # Category 2: Important Dates
    data[:date_issued] = job_response["DateIssued"] rescue nil
    data[:date_created] = job_response["DateIssued"] rescue nil
    data[:completion_date] = job_response["CompletedDate"] rescue nil
    data[:completed_date] = job_response["CompletedDate"] rescue nil
    data[:last_modified_date] = job_response["DateModified"] rescue nil
    
    # Category 3: People & Assignments
    data[:salesperson] = job_response["Salesperson"]["Name"] rescue nil
    data[:sales_person_id] = job_response["Salesperson"]["ID"] rescue nil
    data[:project_manager] = job_response["ProjectManager"]["Name"] rescue nil
    data[:manager_id] = job_response["ProjectManager"]["ID"] rescue nil
    
    # Technician information
    if present?(job_response["Technicians"]) && job_response["Technicians"].is_a?(Array) && job_response["Technicians"].any?
      data[:assigned_technicians] = job_response["Technicians"].map { |t| t["Name"] }.compact.join(", ") rescue nil
      data[:technician_id] = job_response["Technicians"].first["ID"] rescue nil
    elsif present?(job_response["Technician"])
      data[:assigned_technicians] = job_response["Technician"]["Name"] rescue nil
      data[:technician_id] = job_response["Technician"]["ID"] rescue nil
    end
    
    # Customer and site information
    if present?(job_response["CustomerContact"])
      data[:primary_contact_name] = "#{job_response['CustomerContact']['GivenName']} #{job_response['CustomerContact']['FamilyName']}".strip rescue nil
      data[:primary_customer_contact_id] = job_response["CustomerContact"]["ID"] rescue nil
    end
    
    if present?(job_response["SiteContact"])
      data[:site_contact_name] = "#{job_response['SiteContact']['GivenName']} #{job_response['SiteContact']['FamilyName']}".strip rescue nil
    end
    
    data[:simpro_customer_id] = job_response["Customer"]["ID"] rescue nil
    data[:simpro_company_id] = job_response["Customer"]["ID"] rescue nil
    data[:simpro_company_name] = job_response["Customer"]["CompanyName"] rescue nil
    data[:simpro_customer_contract_id] = job_response["CustomerContract"]["ID"] rescue nil
    # Note: site and site_id already extracted above for job name generation
    
    # Category 4: Financial Information
    data[:total_price_ex_tax] = job_response["Total"]["ExTax"] rescue nil
    data[:total_price_inc_tax] = job_response["Total"]["IncTax"] rescue nil
    data[:total_amount_inc_tax] = job_response["Total"]["IncTax"] rescue nil
    data[:invoiced_value] = job_response["Totals"]["InvoicedValue"] rescue nil
    
    # Extract actual gross margin PERCENTAGE (not dollar amount!)
    # Try Percentage first, then Estimate, then Revised
    gross_margin_pct = nil
    if present?(job_response["Totals"]["GrossMargin"])
      gm = job_response["Totals"]["GrossMargin"]
      # Percentage field takes priority
      if present?(gm["Percentage"])
        gross_margin_pct = gm["Percentage"].to_f
      elsif present?(gm["Estimate"])
        gross_margin_pct = gm["Estimate"].to_f
      elsif present?(gm["Revised"])
        gross_margin_pct = gm["Revised"].to_f
      end
    end
    
    # Store as decimal for HubSpot (29.42% = 0.2942)
    data[:actual_gross_margin] = gross_margin_pct ? (gross_margin_pct / 100.0).round(4) : nil
    
    # Calculate invoice percentage  
    # Note: HubSpot expects percentage as decimal (0.0805 = 8.05%), not whole number (8.05)
    if data[:total_amount_inc_tax].to_f > 0 && present?(data[:invoiced_value])
      data[:invoice_percentage] = (data[:invoiced_value].to_f / data[:total_amount_inc_tax].to_f).round(4)
    end
    
    # Category 5: Job Origin & Relationships
    data[:converted_quote_id] = job_response["ConvertedFromQuote"]["ID"] rescue nil
    data[:date_converted_quote] = job_response["ConvertedFromQuote"]["DateConverted"] rescue nil
    
    # Discounted Price from converted quote (Inc GST)
    data[:discounted_price_inc_gst] = job_response["ConvertedFromQuote"]["Total"]["IncTax"] rescue nil
    
    # Job Cost Centres - extract default/primary cost centre name
    if present?(job_response["CostCenters"]) && job_response["CostCenters"].is_a?(Array) && job_response["CostCenters"].any?
      # Get the first/primary cost centre or join all if multiple
      cost_centre_names = job_response["CostCenters"].map { |cc| cc["Name"] }.compact
      data[:job_cost_centres] = cost_centre_names.join(", ") if cost_centre_names.any?
    end
    
    # Category 6: Custom Fields
    if present?(job_response["CustomFields"])
      find_cf = ->(id) { job_response["CustomFields"].find { |cf| cf["CustomField"]["ID"] == id } }
      
      region_field = find_cf.call(111)
      data[:region] = region_field["Value"] rescue nil if region_field
      
      financing_field = find_cf.call(52)
      data[:financing] = financing_field["Value"] rescue nil if financing_field
      
      smartquote_field = find_cf.call(226)
      data[:custom_29_smartrquotelink] = smartquote_field["Value"] rescue nil if smartquote_field
      
      installation_field = find_cf.call(85)
      data[:installation_date] = installation_field["Value"] rescue nil if installation_field
      
      grid_approval_field = find_cf.call(9)
      data[:grid_approval_number] = grid_approval_field["Value"] rescue nil if grid_approval_field
      
      grid_submitted_field = find_cf.call(80)
      data[:grid_approval_submitted_date] = grid_submitted_field["Value"] rescue nil if grid_submitted_field
      
      metering_field = find_cf.call(7)
      data[:metering_requested_date] = metering_field["Value"] rescue nil if metering_field
      
      inspection_field = find_cf.call(6)
      data[:inspection_date] = inspection_field["Value"] rescue nil if inspection_field
      
      ces_field = find_cf.call(11)
      data[:ces_submitted_date] = ces_field["Value"] rescue nil if ces_field
    end
    
    data
  end

  def create_hubspot_job(job_data)
    properties = build_hubspot_properties(job_data)
    
    response = with_retry do
      HTTParty.post(
        "https://api.hubapi.com/crm/v3/objects/p_jobs",
        body: { properties: properties }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@hubspot_token}"
        },
        timeout: 30
      )
    end
    
    if response.success?
      response.parsed_response['id']
    else
      @logger.error "Failed to create job: #{response.code} - #{response.body}"
      nil
    end
  end

  def update_hubspot_job(hubspot_id, job_data)
    properties = build_hubspot_properties(job_data)
    
    # DEBUG: Log what we're sending
    @logger.debug "Updating HubSpot #{hubspot_id} with actual_gross_margin: #{properties['actual_gross_margin']}"
    
    # Don't use with_retry for updates - we want to handle 404s immediately
    response = HTTParty.patch(
      "https://api.hubapi.com/crm/v3/objects/p_jobs/#{hubspot_id}",
      body: { properties: properties }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@hubspot_token}"
      },
      timeout: 30
    )
    
    if response.success?
      true
    elsif response.code == 404
      # Job not found (deleted from HubSpot)
      @logger.warn "Job #{hubspot_id} not found: #{response.code} - #{response.body}"
      :not_found
    else
      @logger.error "Failed to update job #{hubspot_id}: #{response.code} - #{response.body}"
      false
    end
  end

  def build_hubspot_properties(job_data)
    properties = {}
    
    # Basic Information
    properties["jobs"] = job_data[:job_name] if present?(job_data[:job_name])
    properties["stage"] = job_data[:stage] if present?(job_data[:stage])
    properties["job_status"] = job_data[:job_status] if present?(job_data[:job_status])
    properties["status"] = job_data[:job_status] if present?(job_data[:job_status])
    properties["simpro_job_id"] = job_data[:simpro_job_id] if present?(job_data[:simpro_job_id])
    
    # Pipeline Stage
    if present?(job_data[:pipeline_stage])
      properties["hs_pipeline"] = @pipeline_id
      properties["hs_pipeline_stage"] = job_data[:pipeline_stage]
    end
    
    # Dates
    properties["date_issued"] = format_date_for_hubspot(job_data[:date_issued]) if present?(job_data[:date_issued])
    properties["date_created"] = format_date_for_hubspot(job_data[:date_created]) if present?(job_data[:date_created])
    properties["completed_date"] = format_date_for_hubspot(job_data[:completed_date]) if present?(job_data[:completed_date])
    properties["completion_date"] = format_date_for_hubspot(job_data[:completion_date]) if present?(job_data[:completion_date])
    properties["last_modified_date"] = format_date_for_hubspot(job_data[:last_modified_date]) if present?(job_data[:last_modified_date])
    properties["date_converted_quote"] = format_date_for_hubspot(job_data[:date_converted_quote]) if present?(job_data[:date_converted_quote])
    
    # People & Assignments
    properties["salesperson"] = job_data[:salesperson] if present?(job_data[:salesperson])
    properties["sales_person_id"] = job_data[:sales_person_id].to_s if present?(job_data[:sales_person_id])
    properties["project_manager"] = job_data[:project_manager] if present?(job_data[:project_manager])
    properties["manager_id"] = job_data[:manager_id].to_s if present?(job_data[:manager_id])
    properties["assigned_technicians"] = job_data[:assigned_technicians] if present?(job_data[:assigned_technicians])
    properties["technician_id"] = job_data[:technician_id].to_s if present?(job_data[:technician_id])
    properties["primary_contact_name"] = job_data[:primary_contact_name] if present?(job_data[:primary_contact_name])
    properties["primary_customer_contact_id"] = job_data[:primary_customer_contact_id].to_s if present?(job_data[:primary_customer_contact_id])
    properties["site_contact_name"] = job_data[:site_contact_name] if present?(job_data[:site_contact_name])
    
    # Customer & Company
    properties["simpro_customer_id"] = job_data[:simpro_customer_id].to_s if present?(job_data[:simpro_customer_id])
    properties["simpro_company_id"] = job_data[:simpro_company_id].to_s if present?(job_data[:simpro_company_id])
    properties["simpro_company_name"] = job_data[:simpro_company_name] if present?(job_data[:simpro_company_name])
    properties["simpro_customer_contract_id"] = job_data[:simpro_customer_contract_id].to_s if present?(job_data[:simpro_customer_contract_id])
    properties["site"] = job_data[:site] if present?(job_data[:site])
    properties["site_id"] = job_data[:site_id].to_s if present?(job_data[:site_id])
    
    # Financial
    properties["actual_gross_margin"] = job_data[:actual_gross_margin].to_f if present?(job_data[:actual_gross_margin])
    properties["total_amount_inc_tax_"] = job_data[:total_amount_inc_tax].to_f if present?(job_data[:total_amount_inc_tax])
    properties["total_price_inc_tax"] = job_data[:total_price_inc_tax].to_f if present?(job_data[:total_price_inc_tax])
    properties["total_price_ex_tax"] = job_data[:total_price_ex_tax].to_f if present?(job_data[:total_price_ex_tax])
    properties["invoiced_value"] = job_data[:invoiced_value].to_f if present?(job_data[:invoiced_value])
    properties["invoice_percentage"] = job_data[:invoice_percentage].to_f if present?(job_data[:invoice_percentage])
    
    # Relationships
    properties["converted_quote_id"] = job_data[:converted_quote_id].to_s if present?(job_data[:converted_quote_id])
    properties["discounted_price_inc_gst"] = job_data[:discounted_price_inc_gst].to_f if present?(job_data[:discounted_price_inc_gst])
    properties["job_cost_centres"] = job_data[:job_cost_centres] if present?(job_data[:job_cost_centres])
    
    # Custom Fields
    properties["region"] = job_data[:region] if present?(job_data[:region])
    properties["financing"] = job_data[:financing] if present?(job_data[:financing])
    properties["custom_29_smartrquotelink"] = job_data[:custom_29_smartrquotelink] if present?(job_data[:custom_29_smartrquotelink])
    properties["installation_date"] = format_date_for_hubspot(job_data[:installation_date]) if present?(job_data[:installation_date])
    properties["grid_approval_number"] = job_data[:grid_approval_number] if present?(job_data[:grid_approval_number])
    properties["grid_approval_submitted_date"] = format_date_for_hubspot(job_data[:grid_approval_submitted_date]) if present?(job_data[:grid_approval_submitted_date])
    properties["metering_requested_date"] = format_date_for_hubspot(job_data[:metering_requested_date]) if present?(job_data[:metering_requested_date])
    properties["inspection_date"] = format_date_for_hubspot(job_data[:inspection_date]) if present?(job_data[:inspection_date])
    properties["ces_submitted_date"] = format_date_for_hubspot(job_data[:ces_submitted_date]) if present?(job_data[:ces_submitted_date])
    
    properties
  end

  def format_date_for_hubspot(date_value)
    return nil unless present?(date_value)
    
    begin
      if date_value.is_a?(Numeric)
        time = Time.at(date_value < 10000000000 ? date_value : date_value / 1000).utc
        Time.utc(time.year, time.month, time.day).to_i * 1000
      elsif date_value.is_a?(String)
        parsed = Date.parse(date_value)
        Time.utc(parsed.year, parsed.month, parsed.day).to_i * 1000
      else
        nil
      end
    rescue => e
      @logger.warn "Error formatting date '#{date_value}': #{e.message}"
      nil
    end
  end

  def update_simpro_custom_field(job_id, hubspot_id)
    rate_limit_simpro
    
    response = with_retry do
      HTTParty.patch(
        "#{@simpro_url}/jobs/#{job_id}/customFields/262",
        body: { Value: hubspot_id }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@simpro_key}"
        },
        timeout: 30
      )
    end
    
    unless response.success?
      @logger.warn "Failed to update Simpro custom field for job #{job_id}: #{response.code}"
    end
  end

  # === ASSOCIATION METHODS ===
  
  def associate_job_with_related_records(hubspot_job_id, job_response)
    @logger.info "🔗 Creating associations for job #{hubspot_job_id}..."
    
    # 1. Associate Contact (Customer)
    contact_id = find_or_create_contact(job_response)
    if contact_id
      associate_contact_to_job(hubspot_job_id, contact_id)
    else
      @logger.warn "No contact found/created for job #{hubspot_job_id}"
    end
    
    # 2. Associate Site
    site_id = find_or_create_site(job_response)
    if site_id
      associate_site_to_job(hubspot_job_id, site_id)
    else
      @logger.warn "No site found/created for job #{hubspot_job_id}"
    end
    
    # 3. Associate Deal (from converted quote)
    deal_id = find_deal_by_quote_id(job_response)
    if deal_id
      associate_deal_to_job(hubspot_job_id, deal_id)
    else
      @logger.debug "No deal found for job #{hubspot_job_id} (no converted quote or deal not in HubSpot)"
    end
  rescue => e
    @logger.error "Error in associations for job #{hubspot_job_id}: #{e.message}"
  end
  
  # Find or create contact in HubSpot from Simpro customer data
  def find_or_create_contact(job_response)
    return nil unless present?(job_response["Customer"])
    
    customer = job_response["Customer"]
    simpro_customer_id = customer["ID"] rescue nil
    
    return nil unless present?(simpro_customer_id)
    
    # Search by Simpro Customer ID first
    contact_id = search_contact_by_simpro_id(simpro_customer_id)
    return contact_id if contact_id
    
    # Fetch full customer details from Simpro if needed
    @logger.info "📞 Contact not found in HubSpot, fetching from Simpro..."
    rate_limit_simpro
    
    customer_response = with_retry do
      HTTParty.get(
        "#{@simpro_url}/customers/#{simpro_customer_id}",
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@simpro_key}"
        },
        timeout: 30
      )
    end
    
    unless customer_response.success?
      @logger.error "Failed to fetch customer #{simpro_customer_id} from Simpro"
      return nil
    end
    
    customer_data = customer_response.parsed_response
    
    # Extract email for contact creation
    email = customer_data.dig("ContactPerson", "Email") || customer_data["Email"] rescue nil
    
    # If we have email, search by email too
    if present?(email)
      contact_id = search_contact_by_email(email)
      if contact_id
        # Update with Simpro ID and return
        update_contact_simpro_id(contact_id, simpro_customer_id)
        return contact_id
      end
    end
    
    # Create new contact
    create_contact(customer_data, email)
  rescue => e
    @logger.error "Error in find_or_create_contact: #{e.message}"
    nil
  end
  
  def create_contact(customer_data, email)
    # Use email or generate placeholder
    contact_email = email.present? ? email : "noemail+#{customer_data['ID']}@solarhub.com.au"
    
    properties = {
      "email" => contact_email,
      "firstname" => customer_data.dig("ContactPerson", "GivenName") || customer_data["GivenName"] || "",
      "lastname" => customer_data.dig("ContactPerson", "FamilyName") || customer_data["FamilyName"] || "Unknown",
      "phone" => customer_data.dig("ContactPerson", "Phone") || customer_data["Phone"] || "",
      "mobilephone" => customer_data.dig("ContactPerson", "CellPhone") || customer_data["CellPhone"] || "",
      "simpro_customer_id" => customer_data["ID"].to_s
    }
    
    rate_limit_hubspot
    response = with_retry do
      HTTParty.post(
        "https://api.hubapi.com/crm/v3/objects/contacts",
        body: { properties: properties }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@hubspot_token}"
        },
        timeout: 30
      )
    end
    
    if response.success?
      contact_id = response.parsed_response["id"]
      @logger.info "✅ Created new contact #{contact_id} with Simpro ID: #{customer_data['ID']}"
      contact_id
    else
      @logger.error "Failed to create contact: #{response.code} - #{response.body[0..200]}"
      nil
    end
  rescue => e
    @logger.error "Error creating contact: #{e.message}"
    nil
  end
  
  def update_contact_simpro_id(contact_id, simpro_customer_id)
    rate_limit_hubspot
    response = HTTParty.patch(
      "https://api.hubapi.com/crm/v3/objects/contacts/#{contact_id}",
      body: { properties: { "simpro_customer_id" => simpro_customer_id.to_s } }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@hubspot_token}"
      },
      timeout: 30
    )
    
    if response.success?
      @logger.info "✅ Updated contact #{contact_id} with Simpro ID: #{simpro_customer_id}"
    end
  rescue => e
    @logger.error "Error updating contact Simpro ID: #{e.message}"
  end
  
  # Find or create site in HubSpot from Simpro site data
  def find_or_create_site(job_response)
    return nil unless present?(job_response["Site"])
    
    simpro_site_id = job_response["Site"]["ID"] rescue nil
    return nil unless present?(simpro_site_id)
    
    # Search by Simpro Site ID first
    site_id = search_site_by_simpro_id(simpro_site_id)
    return site_id if site_id
    
    # Fetch full site details from Simpro if needed
    @logger.info "🏠 Site not found in HubSpot, fetching from Simpro..."
    rate_limit_simpro
    
    site_response = with_retry do
      HTTParty.get(
        "#{@simpro_url}/sites/#{simpro_site_id}",
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@simpro_key}"
        },
        timeout: 30
      )
    end
    
    unless site_response.success?
      @logger.error "Failed to fetch site #{simpro_site_id} from Simpro"
      return nil
    end
    
    site_data = site_response.parsed_response
    
    # Create new site
    create_site(site_data)
  rescue => e
    @logger.error "Error in find_or_create_site: #{e.message}"
    nil
  end
  
  def create_site(site_data)
    site_name = site_data["Name"].present? ? site_data["Name"].strip : "No Site Name"
    
    properties = {
      "site" => site_name,
      "site_name" => site_name,
      "address" => site_data.dig("Address", "Address") || "",
      "suburb" => site_data.dig("Address", "City") || "",
      "state" => site_data.dig("Address", "State") || "",
      "postcode" => site_data.dig("Address", "PostalCode") || "",
      "country" => site_data.dig("Address", "Country") || "Australia",
      "simpro_site_id" => site_data["ID"].to_s
    }
    
    rate_limit_hubspot
    response = with_retry do
      HTTParty.post(
        "https://api.hubapi.com/crm/v3/objects/p_sites",
        body: { properties: properties }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@hubspot_token}"
        },
        timeout: 30
      )
    end
    
    if response.success?
      site_id = response.parsed_response["id"]
      @logger.info "✅ Created new site #{site_id} (#{site_name}) with Simpro ID: #{site_data['ID']}"
      site_id
    else
      @logger.error "Failed to create site: #{response.code} - #{response.body[0..200]}"
      nil
    end
  rescue => e
    @logger.error "Error creating site: #{e.message}"
    nil
  end
  
  # Create association between job and contact using default association endpoint
  # Association Type ID: 67
  def associate_contact_to_job(job_id, contact_id)
    rate_limit_hubspot
    response = HTTParty.put(
      "https://api.hubapi.com/crm/v4/objects/p_jobs/#{job_id}/associations/default/contacts/#{contact_id}",
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@hubspot_token}"
      },
      timeout: 30
    )
    
    if response.success?
      @logger.info "✅ Associated contact #{contact_id} with job #{job_id}"
      true
    else
      @logger.warn "Failed to associate contact: #{response.code} - #{response.body[0..200]}"
      false
    end
  rescue => e
    @logger.error "Error associating contact: #{e.message}"
    false
  end
  
  # Create association between job and site using default association endpoint  
  # Association Type ID: 104 (Work Location)
  def associate_site_to_job(job_id, site_id)
    rate_limit_hubspot
    response = HTTParty.put(
      "https://api.hubapi.com/crm/v4/objects/p_jobs/#{job_id}/associations/default/p_sites/#{site_id}",
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@hubspot_token}"
      },
      timeout: 30
    )
    
    if response.success?
      @logger.info "✅ Associated site #{site_id} with job #{job_id}"
      true
    else
      @logger.warn "Failed to associate site: #{response.code} - #{response.body[0..200]}"
      false
    end
  rescue => e
    @logger.error "Error associating site: #{e.message}"
    false
  end
  
  # Create association between job and deal
  # Association Type ID: 63
  def associate_deal_to_job(job_id, deal_id)
    rate_limit_hubspot
    response = HTTParty.put(
      "https://api.hubapi.com/crm/v4/objects/p_jobs/#{job_id}/associations/default/deals/#{deal_id}",
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@hubspot_token}"
      },
      timeout: 30
    )
    
    if response.success?
      @logger.info "✅ Associated deal #{deal_id} with job #{job_id}"
      true
    else
      @logger.warn "Failed to associate deal: #{response.code} - #{response.body[0..200]}"
      false
    end
  rescue => e
    @logger.error "Error associating deal: #{e.message}"
    false
  end
  
  # Find deal by Simpro quote ID
  def find_deal_by_quote_id(job_response)
    quote_id = job_response.dig("ConvertedFromQuote", "ID") rescue nil
    return nil unless present?(quote_id)
    
    body_json = {
      "filterGroups" => [
        {
          "filters" => [
            {
              "propertyName" => "simpro_quote_id",
              "operator" => "EQ",
              "value" => quote_id.to_s
            }
          ]
        }
      ]
    }
    
    rate_limit_hubspot
    response = HTTParty.post(
      "https://api.hubapi.com/crm/v3/objects/deals/search",
      body: body_json.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@hubspot_token}"
      },
      timeout: 30
    )
    
    if response.success? && present?(response["results"])
      deal_id = response["results"].first["id"]
      @logger.info "📋 Found deal #{deal_id} for quote #{quote_id}"
      deal_id
    else
      nil
    end
  rescue => e
    @logger.error "Error searching for deal: #{e.message}"
    nil
  end
  
  def search_contact_by_email(email)
    return nil unless present?(email)
    
    body_json = {
      "filterGroups" => [
        {
          "filters" => [
            {
              "propertyName" => "email",
              "operator" => "EQ",
              "value" => email
            }
          ]
        }
      ]
    }
    
    rate_limit_hubspot
    response = HTTParty.post(
      "https://api.hubapi.com/crm/v3/objects/contacts/search",
      body: body_json.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@hubspot_token}"
      },
      timeout: 30
    )
    
    if response.success? && present?(response["results"])
      response["results"].first["id"]
    else
      nil
    end
  rescue => e
    @logger.error "Error searching contact by email: #{e.message}"
    nil
  end
  
  def search_contact_by_simpro_id(simpro_customer_id)
    return nil unless present?(simpro_customer_id)
    
    body_json = {
      "filterGroups" => [
        {
          "filters" => [
            {
              "propertyName" => "simpro_customer_id",
              "operator" => "EQ",
              "value" => simpro_customer_id.to_s
            }
          ]
        }
      ]
    }
    
    rate_limit_hubspot
    response = HTTParty.post(
      "https://api.hubapi.com/crm/v3/objects/contacts/search",
      body: body_json.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@hubspot_token}"
      },
      timeout: 30
    )
    
    if response.success? && present?(response["results"])
      response["results"].first["id"]
    else
      nil
    end
  rescue => e
    @logger.error "Error searching contact by Simpro ID: #{e.message}"
    nil
  end
  
  def search_site_by_simpro_id(simpro_site_id)
    return nil unless present?(simpro_site_id)
    
    body_json = {
      "filterGroups" => [
        {
          "filters" => [
            {
              "propertyName" => "simpro_site_id",
              "operator" => "EQ",
              "value" => simpro_site_id.to_s
            }
          ]
        }
      ]
    }
    
    rate_limit_hubspot
    response = HTTParty.post(
      "https://api.hubapi.com/crm/v3/objects/p_sites/search",
      body: body_json.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@hubspot_token}"
      },
      timeout: 30
    )
    
    if response.success? && present?(response["results"])
      response["results"].first["id"]
    else
      nil
    end
  rescue => e
    @logger.error "Error searching site by Simpro ID: #{e.message}"
    nil
  end

  def rate_limit_simpro
    time_since_last = Time.now - @last_simpro_request
    sleep_time = (1.0 / @rate_limit_simpro) - time_since_last
    sleep(sleep_time) if sleep_time > 0
    @last_simpro_request = Time.now
  end

  def rate_limit_hubspot
    time_since_last = Time.now - @last_hubspot_request
    sleep_time = (1.0 / @rate_limit_hubspot) - time_since_last
    sleep(sleep_time) if sleep_time > 0
    @last_hubspot_request = Time.now
  end

  def with_retry(max_attempts: @max_retries)
    attempts = 0
    begin
      attempts += 1
      yield
    rescue => e
      if attempts < max_attempts
        @logger.warn "Attempt #{attempts} failed: #{e.message}. Retrying in #{@retry_delay}s..."
        sleep @retry_delay
        retry
      else
        @logger.error "All #{max_attempts} attempts failed: #{e.message}"
        raise
      end
    end
  end

  def initialize_report
    CSV.open(@report_file, 'w') do |csv|
      csv << [
        'Simpro Job ID',
        'Job Name',
        'Status',
        'HubSpot Job ID',
        'Message',
        'Timestamp'
      ]
    end
  end

  def write_report_row(simpro_id, job_name, status, message)
    CSV.open(@report_file, 'a') do |csv|
      csv << [
        simpro_id,
        job_name,
        status,
        message.to_s.include?('188') ? message : '',
        message,
        Time.now.strftime('%Y-%m-%d %H:%M:%S')
      ]
    end
  end

  def print_summary(duration)
    @logger.info ""
    @logger.info "=" * 80
    @logger.info "Sync Summary"
    @logger.info "=" * 80
    @logger.info "Total Jobs: #{@stats[:total_jobs]}"
    @logger.info "Created: #{@stats[:created]}"
    @logger.info "Updated: #{@stats[:updated]}"
    @logger.info "Skipped: #{@stats[:skipped]}"
    @logger.info "Failed: #{@stats[:failed]}"
    @logger.info "Duration: #{duration}s"
    @logger.info ""
    @logger.info "Report saved to: #{@report_file}"
    @logger.info "=" * 80
    
    if @stats[:errors].any?
      @logger.info ""
      @logger.info "Errors:"
      @stats[:errors].each do |error|
        @logger.error "Job #{error[:job_id]}: #{error[:error]}"
      end
    end
  end
end

# Run the sync
if __FILE__ == $0
  sync = JobsSync.new
  sync.run
end

