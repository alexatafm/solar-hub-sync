require 'dotenv/load'
require_relative 'sync_jobs'

class TestGrossMargin < JobsSync
  def test_single_job(job_id)
    puts "=" * 80
    puts "Testing Gross Margin Fix for Job #{job_id}"
    puts "=" * 80
    
    # Fetch job from Simpro
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
      puts "❌ Failed to fetch job from Simpro"
      return
    end
    
    job_response = response.parsed_response
    
    # Extract fields
    job_data = extract_job_fields(job_response)
    
    puts ""
    puts "📊 EXTRACTED DATA:"
    puts "  Job Name: #{job_data[:job_name]}"
    puts "  Gross Margin: #{job_data[:actual_gross_margin]} (displays as #{(job_data[:actual_gross_margin].to_f * 100).round(2)}%)"
    puts "  Invoice %: #{job_data[:invoice_percentage]} (displays as #{(job_data[:invoice_percentage] * 100).round(2)}%)"
    puts ""
    
    # Build HubSpot properties
    properties = build_hubspot_properties(job_data)
    
    puts "🎯 HUBSPOT PROPERTIES:"
    puts "  jobs (name): '#{properties['jobs']}'"
    puts "  simpro_job_id: #{properties['simpro_job_id']}"
    puts "  hs_pipeline_stage: #{properties['hs_pipeline_stage']}"
    puts "  actual_gross_margin: #{properties['actual_gross_margin']}"
    puts "  invoice_percentage: #{properties['invoice_percentage']}"
    puts "  total_amount_inc_tax_: #{properties['total_amount_inc_tax_']}"
    puts "  invoiced_value: #{properties['invoiced_value']}"
    puts ""
    
    # Update in HubSpot
    existing_hubspot_id = job_response.dig("CustomFields")&.find { |cf| cf.dig("CustomField", "ID") == 262 }&.dig("Value")
    
    if existing_hubspot_id
      puts "📤 Updating HubSpot Job #{existing_hubspot_id}..."
      success = update_hubspot_job(existing_hubspot_id, job_data)
      
      if success
        puts "✅ Successfully updated!"
        puts ""
        
        # Fetch back from HubSpot to verify
        puts "🔍 Verifying in HubSpot..."
        verify_response = HTTParty.get(
          "#{@hubspot_url}/crm/v3/objects/#{@hubspot_object_type}/#{existing_hubspot_id}",
          query: { 'properties' => 'jobs,actual_gross_margin,invoice_percentage,total_amount_inc_tax_,invoiced_value' },
          headers: {
            'Authorization' => "Bearer #{@hubspot_key}",
            'Content-Type' => 'application/json'
          }
        )
        
        if verify_response.success?
          props = verify_response.parsed_response['properties']
          gross_margin_display = (props['actual_gross_margin'].to_f * 100).round(2)
          invoice_pct_display = (props['invoice_percentage'].to_f * 100).round(2)
          
          puts ""
          puts "✅ VERIFICATION FROM HUBSPOT:"
          puts "  Job Name: #{props['jobs']}"
          puts "  Gross Margin: #{props['actual_gross_margin']} → Displays as: #{gross_margin_display}%"
          puts "  Invoice %: #{props['invoice_percentage']} → Displays as: #{invoice_pct_display}%"
          puts "  Total Inc Tax: $#{props['total_amount_inc_tax_']}"
          puts "  Invoiced: $#{props['invoiced_value']}"
          puts ""
          
          if gross_margin_display == 29.42
            puts "🎉 SUCCESS! Gross margin is correct (29.42%)"
          else
            puts "❌ ERROR: Expected 29.42%, got #{gross_margin_display}%"
          end
        end
      else
        puts "❌ Update failed"
      end
    else
      puts "❌ No HubSpot ID found"
    end
  end
end

tester = TestGrossMargin.new
tester.test_single_job(33830)
