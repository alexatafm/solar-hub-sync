require 'dotenv/load'
require_relative 'sync_jobs'

class DebugJobSync < JobsSync
  def debug_single_job(job_id, hubspot_id)
    # Fetch job
    response = HTTParty.get(
      "#{@simpro_url}/jobs/#{job_id}",
      headers: {
        'Authorization' => "Bearer #{@simpro_key}"
      }
    )
    
    if response.success?
      job = response.parsed_response
      
      puts '=' * 80
      puts "DEBUG: Gross Margin for Job #{job_id}"
      puts '=' * 80
      puts ''
      
      # Extract fields
      job_data = extract_job_fields(job)
      
      puts "Gross Margin from Simpro:"
      puts "  GrossMargin.Actual: $#{job['Totals']['GrossMargin']['Actual'] rescue 'N/A'}"
      puts "  GrossMargin.Estimate: #{job['Totals']['GrossMargin']['Estimate'] rescue 'N/A'}%"
      puts "  GrossMargin.Percentage: '#{job['Totals']['GrossMargin']['Percentage'] rescue 'N/A'}'"
      puts ""
      puts "Extracted value for HubSpot:"
      puts "  actual_gross_margin: #{job_data[:actual_gross_margin]}"
      puts "  Displays as: #{(job_data[:actual_gross_margin].to_f * 100).round(2)}%"
      puts ""
      
      # Build properties
      props = build_hubspot_properties(job_data)
      puts "HubSpot property value:"
      puts "  properties['actual_gross_margin']: #{props['actual_gross_margin']}"
      puts ""
      
      # Update HubSpot
      puts "Updating HubSpot job #{hubspot_id}..."
      result = update_hubspot_job(hubspot_id, job_data)
      puts "Result: #{result ? 'Success' : 'Failed'}"
      
      # Verify in HubSpot
      sleep 2
      puts ""
      puts "Verifying in HubSpot..."
      verify_response = HTTParty.get(
        "https://api.hubapi.com/crm/v3/objects/2-185689031/#{hubspot_id}",
        query: { 'properties' => 'actual_gross_margin' },
        headers: { 'Authorization' => "Bearer #{@hubspot_token}" }
      )
      
      if verify_response.success?
        gm_val = verify_response.parsed_response['properties']['actual_gross_margin'].to_f
        gm_display = (gm_val * 100).round(2)
        puts "  HubSpot value: #{gm_val}"
        puts "  Displays as: #{gm_display}%"
        puts ""
        
        if gm_display == 29.5
          puts "✅ SUCCESS! Gross margin is correct!"
        else
          puts "❌ FAILED! Expected 29.5%, got #{gm_display}%"
        end
      end
    end
  end
end

if __FILE__ == $0
  sync = DebugJobSync.new
  sync.debug_single_job(33865, 192313502139)
end

