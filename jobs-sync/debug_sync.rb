require 'dotenv/load'
require_relative 'sync_jobs'

class DebugJobsSync < JobsSync
  def test_debug(job_id)
    puts "=" * 80
    puts "Debug Test for Job #{job_id}"
    puts "=" * 80
    
    # Fetch from Simpro
    response = with_retry do
      HTTParty.get(
        "#{@simpro_url}/jobs/#{job_id}",
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@simpro_key}"
        }
      )
    end
    
    if !response.success?
      puts "❌ Failed to fetch job"
      return
    end
    
    job_response = response.parsed_response
    
    puts ""
    puts "Step 1: Raw Simpro Data"
    puts "-" * 80
    gm = job_response["Totals"]["GrossMargin"]
    puts "GrossMargin.Actual: $#{gm['Actual']}"
    puts "GrossMargin.Estimate: #{gm['Estimate']}%"
    puts "GrossMargin.Percentage: '#{gm['Percentage']}'"
    
    puts ""
    puts "Step 2: Extracting Fields"
    puts "-" * 80
    job_data = extract_job_fields(job_response)
    puts "job_data[:actual_gross_margin] = #{job_data[:actual_gross_margin]}"
    puts "Displays as: #{(job_data[:actual_gross_margin].to_f * 100).round(2)}%"
    
    puts ""
    puts "Step 3: Building HubSpot Properties"
    puts "-" * 80
    properties = build_hubspot_properties(job_data)
    puts "properties['actual_gross_margin'] = #{properties['actual_gross_margin']}"
    puts "Displays as: #{(properties['actual_gross_margin'].to_f * 100).round(2)}%"
    
    puts ""
    puts "Step 4: Updating HubSpot"
    puts "-" * 80
    existing_hubspot_id = job_response.dig("CustomFields")&.find { |cf| cf.dig("CustomField", "ID") == 262 }&.dig("Value")
    
    if existing_hubspot_id
      puts "Updating HubSpot job #{existing_hubspot_id}..."
      success = update_hubspot_job(existing_hubspot_id, job_data)
      puts success ? "✅ Update successful" : "❌ Update failed"
      
      # Verify
      if success
        puts ""
        puts "Step 5: Verifying in HubSpot"
        puts "-" * 80
        verify_response = HTTParty.get(
          "#{@hubspot_url}/crm/v3/objects/#{@hubspot_object_type}/#{existing_hubspot_id}",
          query: { 'properties' => 'jobs,actual_gross_margin' },
          headers: {
            'Authorization' => "Bearer #{@hubspot_key}",
            'Content-Type' => 'application/json'
          }
        )
        
        if verify_response.success?
          props = verify_response.parsed_response['properties']
          puts "HubSpot value: #{props['actual_gross_margin']}"
          puts "Displays as: #{(props['actual_gross_margin'].to_f * 100).round(2)}%"
        end
      end
    else
      puts "❌ No HubSpot ID found"
    end
  end
end

if __FILE__ == $0
  debug = DebugJobsSync.new
  debug.test_debug(33865)
end

