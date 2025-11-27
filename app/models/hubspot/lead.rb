module Hubspot
  class Lead
    require 'base64'
    
    LEAD_PATH = "https://api.hubapi.com/crm/v3/objects/leads"
    
    # Helper method to encode file fields
    def self.encode_file_field(file_data)
      return nil if file_data.blank?
      return file_data if file_data.is_a?(String) && file_data.start_with?('data:')
      
      if file_data.is_a?(String)
        "data:application/pdf;base64,#{Base64.encode64(file_data)}"
      elsif file_data.respond_to?(:read)
        "data:application/pdf;base64,#{Base64.encode64(file_data.read)}"
      else
        file_data
      end
    end

    def self.update_quote_id(quote_id,lead_id)

       body_json = {
        "properties": {
          "simpro_quote_id": quote_id
        }
      }
      HTTParty.patch("#{LEAD_PATH}/#{lead_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
    end

    def self.associate_company(company_id,lead_id)
      body_json =   [
        {
          "associationCategory": "HUBSPOT_DEFINED",
          "associationTypeId": 611
        }
    ]
    response = HTTParty.put("https://api.hubapi.com/crm/v4/objects/company/#{company_id.to_i}/associations/lead/#{lead_id.to_i}",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
  end

    def self.create_update_lead(contact_id,lead_properties)
      existing_lead = Hubspot::Lead.find_lead(contact_id)
      date_visit =   Time.now.to_date.midnight.to_time.to_i*1000  rescue ""

      if lead_properties["properties"]["assigned_consultant"].present? && lead_properties["properties"]["date_of_booking"].present? && lead_properties["properties"]["time_slot_of_booking"].present?
        hs_pipeline_stage = '1576485344'
      else
        hs_pipeline_stage = '1576207821'
      end
      
      body_json = {
        "properties": {
        "hs_lead_name": lead_properties["properties"]["firstname"] + " " + lead_properties["properties"]["lastname"] + " - " + lead_properties["properties"]["address"],
        "actewagl_or_agl_number": lead_properties["properties"]["actewagl_or_agl_account_holder"],
        "assigned_consultant": lead_properties["properties"]["assigned_consultant"],
        "concession_card": lead_properties["properties"]["concession_card"],
        "concession_card_details": lead_properties["properties"]["concession_card_details"],
        "contact_hubspot_id": lead_properties["properties"]["hs_object_id"],
        "customer_type": lead_properties["properties"]["customer_type"],
        "date_of_booking": lead_properties["properties"]["date_of_booking"],
        "first_name": lead_properties["properties"]["firstname"],
        "how_did_you_hear_about_solarhub_": lead_properties["properties"]["how_did_you_hear_about_solarhub_"],
        "interested_solutions": lead_properties["properties"]["interested_solutions"],
        "is_there_anything_else_you_would_like_to_tell_us": lead_properties["properties"]["is_there_anything_else_you_would_like_to_tell_us"],
        "last_name": lead_properties["properties"]["lastname"],
        "power_bills": encode_file_field(lead_properties["properties"]["power_bills"]),
        "unit__": lead_properties["properties"]["unit__"],
        "street_address": lead_properties["properties"]["address"],
        "state": lead_properties["properties"]["hs_state_code"],
        "suburb": lead_properties["properties"]["city"],
        "territory": lead_properties["properties"]["territory"],
        "post_code": lead_properties["properties"]["zip"],
        "time_slot_of_booking": lead_properties["properties"]["time_slot_of_booking"],
        "date_of_booking": lead_properties["properties"]["date_of_booking"],
        "hs_pipeline_stage": hs_pipeline_stage
      }
     }


      if existing_lead["results"].blank?
        body_json[:properties][:first_visit] = date_visit
        # Add the required association for lead creation - correct format for v3 API
        body_json[:associations] = [
          {
            "to": {
              "id": contact_id
            },
            "types": [
              {
                "associationCategory": "HUBSPOT_DEFINED",
                "associationTypeId": 578
              }
            ]
          }
        ]
        response = HTTParty.post("#{LEAD_PATH}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      else
        body_json[:properties][:last_visit] = date_visit
        lead_id = existing_lead["results"].first["id"]
        response = HTTParty.patch("#{LEAD_PATH}/#{lead_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      end
      if response.present? && response.success?
        return response
      else
        return false
      end
    end

    def self.update_activity_id(activity_id,lead_id)
      body_json = {
        "properties": {
          "simpro_quote_activity_id": activity_id
        }
      }
      HTTParty.patch("#{LEAD_PATH}/#{lead_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
    end

    def self.associate_contact(contact_id,lead_id)
      body_json =   [
        {
          "associationCategory": "HUBSPOT_DEFINED",
          "associationTypeId": 579
        }
    ]
    response = HTTParty.put("https://api.hubapi.com/crm/v4/objects/contact/#{contact_id.to_i}/associations/lead/#{lead_id.to_i}",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
  end

    def self.find_lead(lead_id)
       body_json =
          {
        "filterGroups":[
          {
            "filters":[
              {
                "propertyName": "contact_hubspot_id",
                "operator": "EQ",
                "value": "#{lead_id}"
              }
            ]
          }
        ]
      }
      response = HTTParty.post("#{LEAD_PATH}/search",:body=> body_json.to_json, :headers => {
           "Content-Type" => "application/json","Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
         })
      return response
    end
  end
end