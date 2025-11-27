module Hubspot
  class Job
    JOB_PATH = "https://api.hubapi.com/crm/v3/objects/p_jobs"

   def self.update_job_id(simpro_job_id,hubapi_job_id)

       body_json = {
        "properties": {
          "simpro_job_id": simpro_job_id
        }
      }
      HTTParty.patch("#{JOB_PATH}/#{hubapi_job_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
    end

    def self.update_job_fields(hubspot_job_id, job_data)
      properties = {}
      
      # Category 1: Basic Job Information
      properties["jobs"] = job_data[:job_name] if job_data[:job_name].present?
      properties["stage"] = job_data[:stage] if job_data[:stage].present?
      properties["job_status"] = job_data[:job_status] if job_data[:job_status].present?
      
      # Category 2: Important Dates
      # Convert dates to milliseconds timestamp if present
      if job_data[:date_issued].present?
        properties["date_issued"] = format_date_for_hubspot(job_data[:date_issued])
      end
      
      if job_data[:completion_date].present?
        properties["completion_date"] = format_date_for_hubspot(job_data[:completion_date])
      end
      
      if job_data[:last_modified_date].present?
        properties["last_modified_date"] = format_date_for_hubspot(job_data[:last_modified_date])
      end
      
      # Category 3: People & Assignments
      properties["salesperson"] = job_data[:salesperson] if job_data[:salesperson].present?
      properties["project_manager"] = job_data[:project_manager] if job_data[:project_manager].present?
      properties["primary_contact_name"] = job_data[:primary_contact_name] if job_data[:primary_contact_name].present?
      properties["site_contact_name"] = job_data[:site_contact_name] if job_data[:site_contact_name].present?
      
      # Category 4: Financial Information
      if job_data[:total_amount_inc_tax].present?
        properties["total_amount_inc_tax_"] = job_data[:total_amount_inc_tax].to_f
      end
      
      if job_data[:invoiced_value].present?
        properties["invoiced_value"] = job_data[:invoiced_value].to_f
      end
      
      if job_data[:invoice_percentage].present?
        properties["invoice_percentage"] = job_data[:invoice_percentage].to_f
      end
      
      # Category 5: Job Origin & Relationships
      if job_data[:converted_from_quote].present?
        properties["converted_from_quote"] = job_data[:converted_from_quote]
      end
      
      # Category 6: Custom Fields - Region validation and solar-specific fields
      if job_data[:region].present?
        valid_regions = [
          "Illawara Region",
          "South Coast NSW Region",
          "Canberra Region",
          "Snowy Region"
        ]
        
        # Only set region if it matches one of the valid options
        if valid_regions.include?(job_data[:region])
          properties["region"] = job_data[:region]
        end
      end
      
      # Solar-specific custom field dates
      if job_data[:installation_date].present?
        properties["installation_date"] = format_date_for_hubspot(job_data[:installation_date])
      end
      
      if job_data[:grid_approval_submitted_date].present?
        properties["grid_approval_submitted_date"] = format_date_for_hubspot(job_data[:grid_approval_submitted_date])
      end
      
      if job_data[:metering_requested_date].present?
        properties["metering_requested_date"] = format_date_for_hubspot(job_data[:metering_requested_date])
      end
      
      if job_data[:inspection_date].present?
        properties["inspection_date"] = format_date_for_hubspot(job_data[:inspection_date])
      end
      
      if job_data[:ces_submitted_date].present?
        properties["ces_submitted_date"] = format_date_for_hubspot(job_data[:ces_submitted_date])
      end
      
      # Solar-specific text/number fields
      if job_data[:grid_approval_number].present?
        properties["grid_approval_number"] = job_data[:grid_approval_number]
      end

      # Only make API call if we have properties to update
      if properties.present?
        body_json = {
          "properties": properties
        }
        
        response = HTTParty.patch("#{JOB_PATH}/#{hubspot_job_id}/",
          body: body_json.to_json,
          headers: { 
            'Content-Type' => 'application/json',
            "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" 
          })
          
        if response.success?
          puts "✅ Updated HubSpot Job #{hubspot_job_id} with #{properties.keys.count} fields"
          puts "   Updated fields: #{properties.keys.join(', ')}"
        else
          puts "❌ Failed to update HubSpot Job #{hubspot_job_id}: #{response.code} - #{response.body}"
        end
        
        return response
      else
        puts "⚠️  No properties to update for HubSpot Job #{hubspot_job_id}"
      end
    end

    private

    def self.format_date_for_hubspot(date_value)
      # HubSpot expects dates as milliseconds timestamp
      # simPRO typically returns dates in ISO format or as timestamps
      return nil unless date_value.present?
      
      begin
        if date_value.is_a?(Numeric)
          # Already a timestamp, convert to milliseconds if needed
          date_value < 10000000000 ? date_value * 1000 : date_value
        elsif date_value.is_a?(String)
          # Parse ISO date string and convert to milliseconds
          Time.parse(date_value).to_i * 1000
        elsif date_value.respond_to?(:to_time)
          date_value.to_time.to_i * 1000
        else
          nil
        end
      rescue => e
        puts "⚠️  Error formatting date '#{date_value}': #{e.message}"
        nil
      end
    end
  end
end