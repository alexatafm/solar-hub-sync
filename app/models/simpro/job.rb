module Simpro
  class Job
    def self.create_job(job_details,customer_id,site_id,sales_id)
      created_date = Time.at(job_details["hs_createdate"]["value"].to_i/1000).to_date.strftime('%Y-%m-%d')

     if sales_id.present?
             body_json = {
            "Customer": customer_id.first,
            "Site": site_id.first,
            "Type": "Service",
            "DateIssued": created_date,
            "Name": job_details["jobs"]["value"],
            "Stage": "Progress",
            "Salesperson": sales_id,
            "Status": 132,
            }
          else
             body_json = {
            "Customer": customer_id.first,
            "Site": site_id.first,
            "Type": "Service",
            "DateIssued": created_date,
            "Name": job_details["jobs"]["value"],
            "Stage": "Progress",
            "Status": 132,
            }
          end

          response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/jobs/",:body=> body_json.to_json, :headers => {
            "Content-Type" => "application/json",
             "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
          })
          
          if response.present? && response.success?
            simpro_job_id = response["ID"]
            Hubspot::Job.update_job_id(simpro_job_id,job_details["hs_object_id"]["value"])
            Simpro::Job.update_simpro_id(simpro_job_id,job_details["simpro_job_id"]["value"])
          end

    end

  

    def self.create_update_ticket_job(job_details,customer_id,site_id)
      created_date = Time.at(job_details["hs_createdate"]["value"].to_i/1000).to_date.strftime('%Y-%m-%d')
      simpro_job_id = job_details["simpro_job_id"]["value"] rescue nil

      body_json = {
        "Customer": customer_id.first,
        "Site": site_id.first,
        "Type": "Service",
        "DateIssued": created_date,
        "Name": job_details["jobs"]["value"],
        "Stage": "Progress",
        "Status": 132,
      }
      if simpro_job_id.present?
        response = HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/jobs/#{simpro_job_id}",:body=> body_json.to_json, :headers => {
          "Content-Type" => "application/json",
           "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
      else
        response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/jobs/",:body=> body_json.to_json, :headers => {
          "Content-Type" => "application/json",
           "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
        simpro_job_id = response["ID"]
      end
      
    end

    def self.update_simpro_id(simpro_job_id,hubapi_job_id)
      body_json = {
        "Value": hubapi_job_id
      }
      response = HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/jobs/#{simpro_job_id}/customFields/262",:body=> body_json.to_json, :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })
    end

    def self.webhook_job(job_id)
      # Fetch comprehensive job details from simPRO API
      query = {
        "columns" => "ID,Name,Stage,Status,DateIssued,DateCompleted,DateModified," \
                     "Customer,Site,Staff,Salesperson,ProjectManager," \
                     "TotalExTax,TotalIncTax,TaxAmount,InvoicedValue,CustomFields"
      }
      
      job_response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/jobs/#{job_id}", 
        query: query,
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })

      if job_response.present? && job_response.success?
        job_data = extract_job_fields(job_response)
        
        # Update HubSpot job if we have the ID
        if job_data[:hubspot_job_id].present?
          Hubspot::Job.update_job_fields(job_data[:hubspot_job_id], job_data)
        else
          puts "No HubSpot Job ID found for simPRO Job #{job_id}"
        end
      else
        puts "Failed to fetch job #{job_id} from simPRO"
      end
    end

    private

    def self.extract_job_fields(job_response)
      data = {}
      
      # Find HubSpot job ID from custom field 262
      if job_response["CustomFields"].present?
        hubspot_field = job_response["CustomFields"].find { |cf| cf["ID"] == 262 }
        data[:hubspot_job_id] = hubspot_field["Value"] rescue nil if hubspot_field
      end

      # Category 1: Basic Job Information
      data[:job_name] = job_response["Name"] rescue nil
      data[:stage] = job_response["Stage"] rescue nil
      data[:job_status] = job_response["Status"]["Name"] rescue nil
      
      # Category 2: Important Dates
      data[:date_issued] = job_response["DateIssued"] rescue nil
      data[:completion_date] = job_response["DateCompleted"] rescue nil
      data[:last_modified_date] = job_response["DateModified"] rescue nil
      
      # Category 3: People & Assignments
      data[:salesperson] = job_response["Salesperson"]["Name"] rescue nil
      data[:project_manager] = job_response["ProjectManager"]["Name"] rescue nil
      
      # Get customer contact and site contact names
      data[:primary_contact_name] = job_response["Customer"]["Contact"]["Name"] rescue nil
      data[:site_contact_name] = job_response["Site"]["Contact"]["Name"] rescue nil
      
      # Category 4: Financial Information
      data[:total_amount_inc_tax] = job_response["TotalIncTax"] rescue nil
      data[:invoiced_value] = job_response["InvoicedValue"] rescue nil
      
      # Calculate invoice percentage if we have both values
      if data[:total_amount_inc_tax].present? && data[:invoiced_value].present? && 
         data[:total_amount_inc_tax].to_f > 0
        data[:invoice_percentage] = (data[:invoiced_value].to_f / data[:total_amount_inc_tax].to_f * 100).round(2)
      end
      
      # Category 5: Job Origin & Relationships
      data[:converted_from_quote] = job_response["ConvertedFromQuote"]["ID"] rescue nil
      
      # Category 6: Custom Fields - Region and Solar-specific fields
      if job_response["CustomFields"].present?
        # Region (CF 111)
        region_field = job_response["CustomFields"].find { |cf| cf["ID"] == 111 }
        data[:region] = region_field["Value"] rescue nil if region_field
        
        # Installation date (CF 85)
        installation_field = job_response["CustomFields"].find { |cf| cf["ID"] == 85 }
        data[:installation_date] = installation_field["Value"] rescue nil if installation_field
        
        # Grid approval number (CF 9)
        grid_approval_field = job_response["CustomFields"].find { |cf| cf["ID"] == 9 }
        data[:grid_approval_number] = grid_approval_field["Value"] rescue nil if grid_approval_field
        
        # Grid approval submitted date (CF 80)
        grid_submitted_field = job_response["CustomFields"].find { |cf| cf["ID"] == 80 }
        data[:grid_approval_submitted_date] = grid_submitted_field["Value"] rescue nil if grid_submitted_field
        
        # Metering requested date (CF 7)
        metering_field = job_response["CustomFields"].find { |cf| cf["ID"] == 7 }
        data[:metering_requested_date] = metering_field["Value"] rescue nil if metering_field
        
        # Inspection date (CF 6)
        inspection_field = job_response["CustomFields"].find { |cf| cf["ID"] == 6 }
        data[:inspection_date] = inspection_field["Value"] rescue nil if inspection_field
        
        # CES submitted date (CF 11)
        ces_field = job_response["CustomFields"].find { |cf| cf["ID"] == 11 }
        data[:ces_submitted_date] = ces_field["Value"] rescue nil if ces_field
      end
      
      data
    end
  end
end