
module Hubspot
  # Simpro company OBJECT

  class Deal
    DEAL_PATH='https://api.hubapi.com/crm/v3/objects/deals'

  

  def self.get_deal_associated_contact(deal_id)
      body_json = 
     {"inputs":[{"id": "#{deal_id}"}]}
    
      response = HTTParty.get("https://api.hubapi.com/crm/v4/objects/deals/#{deal_id}/associations/contacts", :headers => {
           "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
         })
      
      contact_id = response["results"].first["toObjectId"].to_s rescue nil
      association_label = response["results"].first["associationTypes"].map{|i| i["label"]}.compact.join rescue nil
      return contact_id,association_label
    end

    def self.get_deal_associated_company(deal_id)
      body_json = 
     {"inputs":[{"id": "#{deal_id}"}]}
    
      response = HTTParty.post("https://api.hubapi.com/crm/v3/associations/deal/company/batch/read",:body=> body_json.to_json, :headers => {
           "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
         })
      contact_id = response["results"].first["to"].first["id"] rescue nil
      return contact_id
    end

    def self.associate_company(deal_id,company_id)
      existing_company =  Hubspot::Company.find_company(company_id)
      if existing_company["results"].blank?
        Simpro::Company.webhook_customer(company_id)
        sleep(1)
        existing_company =  Hubspot::Company.find_company(company_id)
      end
      user_id = existing_company["results"].first["id"] rescue nil
      if user_id.present?
      response = HTTParty.put("https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}/associations/companies/#{user_id}/deal_to_company",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      end
    end

    def self.associate_contact(deal_id,company_id)
      existing_user = Hubspot::Contact.find_simpro_user(company_id)
      if existing_user["results"].blank?
        user_response = Simpro::Customer.webhook_individual_customer(company_id)
        sleep(1)
        
        existing_user = Hubspot::Contact.find_simpro_user(company_id)
      end
      user_id = existing_user["results"].first["id"] rescue nil
      if user_id.present? 
        response = HTTParty.put("https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}/associations/contacts/#{user_id}/deal_to_contact",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      end

    end


    def self.update_simpro_id(simpro_id,deal_id,dealname)
      deal_name = simpro_id.to_s + " - " + dealname
      body_json = {
        "properties": {
         "simpro_quote_id":  simpro_id,
         "dealname": deal_name,
          "initial_sync": Time.strptime(Time.now.to_datetime.strftime("%m/%d/%Y %I:%M %p"), "%m/%d/%Y %I:%M %p").to_i * 1000

        }
      }
      response = HTTParty.patch("#{DEAL_PATH}/#{deal_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
    end

    def self.update_simpro_job_id(simpro_id,deal_id,dealname)
      deal_name = simpro_id.to_s + " - " + dealname
      body_json = {
        "properties": {
         "simpro_job_id":  simpro_id,
         "dealname": deal_name,
          "initial_sync": Time.strptime(Time.now.to_datetime.strftime("%m/%d/%Y %I:%M %p"), "%m/%d/%Y %I:%M %p").to_i * 1000

        }
      }
      response = HTTParty.patch("#{DEAL_PATH}/#{deal_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
    end

  def self.update_response(quote_response,deal_id)
      if quote_response["message"].present?
        message =  quote_response["message"]
      else
         message =  "Quote synced successfully Quote id #{ quote_response["ID"]}"
      end
       body_json = {
        "properties": {
          "last_sync_notes": message
        }
      }
      response = HTTParty.patch("#{DEAL_PATH}/#{deal_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
    end


  def self.update_deal_value(quote,timeline_data,deal_id=nil)

    # If deal_id is provided, use it directly (for CSV-based sync)
    # Otherwise, search by quote_id (for webhook-based sync)
    if deal_id.present?
      # Verify the deal exists and has the correct quote_id
      deal_response = HTTParty.get("#{DEAL_PATH}/#{deal_id}", query: { properties: 'simpro_quote_id' }, headers: { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      if deal_response.success? && deal_response['properties']
        existing_deal = { "results" => [{ "id" => deal_id, "properties" => deal_response['properties'] }] }
      else
        existing_deal = { "results" => [] }
      end
    else
      existing_deal =  Hubspot::Deal.find_deal(quote["ID"])
    end
    deal_id = existing_deal["results"].first["id"] rescue nil
    lost_reason = quote["ArchiveReason"]["ArchiveReason"] rescue ""
    createdate = quote["DateIssued"].to_date.midnight.to_time.to_i*1000  rescue ""
    duedate = (quote["DueDate"].to_date.midnight.to_time).to_i*1000  rescue ""
    
    # Build deal name: Quote ID - Quote Name (or Site Name if Quote Name is empty)
    quote_name = quote["Name"].to_s.strip
    if quote_name.present?
      deal_name = quote["ID"].to_s + " - " + quote_name
    else
      # Fallback to Site Name if Quote Name is empty
      site_name = quote.dig("Site", "Name").to_s.strip rescue ""
      if site_name.present?
        deal_name = quote["ID"].to_s + " - " + site_name
      else
        # Final fallback: just Quote ID
        deal_name = quote["ID"].to_s
      end
    end
    lead_id  =  existing_deal["results"].first["properties"]["hubspot_lead_id"] rescue nil
    if quote["Salesperson"].present?
      salesperson = quote["Salesperson"]["Name"]
    else
      salesperson = nil
    end


    if existing_deal.present? && existing_deal["results"].present?
      pipeline = existing_deal["results"].first["properties"]["pipeline"] rescue nil
      
      # Only auto-update deal stages for "default" (Residential Sales) pipeline
      # Commercial (1012446696) and Service (1011198445) pipelines manage stages independently
      if pipeline == "default"
        case quote["Status"]["Name"]
        when "Quote Sent"
          dealstage = 'qualifiedtobuy'
        when "Quote Accepted"
          dealstage = 'closedwon'
        else
          dealstage = existing_deal["results"].first["properties"]["dealstage"] 
        end
        if quote["ArchiveReason"].present?
          dealstage = 'closedlost'
        end
      else
        # For Commercial and Service pipelines, preserve existing stage
        dealstage = existing_deal["results"].first["properties"]["dealstage"] 
      end
    end


  

    sub_total =  quote["Total"]["ExTax"] rescue 0
    gross_p_l_amount = quote["Totals"]["GrossProfitLoss"]["Estimate"] rescue 0
    gross_margin__ = quote["Totals"]["GrossMargin"]["Estimate"].to_f/100 rescue 0
    nett_p_l_amount = quote["Totals"]["NettProfitLoss"]["Estimate"] rescue 0
    nett_margin = quote["Totals"]["NettMargin"]["Estimate"].to_f/100 rescue 0
    labour_hours = quote["Totals"]["ResourcesCost"]["LaborHours"]["Estimate"] rescue 0
    
    # Calculate Net Price (Inc Tax) from primary line items
    net_price_inc_tax = calculate_net_price_inc_tax(quote)
    
    # Calculate Discount Amount (Inc Tax) - quote-level adjustments
    adjusted_ex_tax = quote["Totals"]["Adjusted"]["Estimate"] rescue 0
    discount_amount_inc_tax = (adjusted_ex_tax * 1.1).abs.round(2) rescue 0
    
    # Calculate Final Total After STCs (Inc Tax)
    total_inc_tax = quote["Total"]["IncTax"] rescue 0
    stcs = quote["Totals"]["STCs"] rescue 0
    final_total_after_stcs = (total_inc_tax - stcs).round(2)
    
    # Extract all additional quote fields
    properties = {
      # Existing fields
      "quote_sub_total":  sub_total,
      "gross_p_l_amount": gross_p_l_amount,
      "gross_margin__":   gross_margin__,
      "nett_p_l_amount": nett_p_l_amount,
      "nett_margin":  nett_margin,
      "pipeline":  pipeline,
      "dealname": deal_name,
      "amount":  quote["Total"]["ExTax"],
      "simpro_quote_id": quote["ID"],
      "createdate": createdate,
      "dealstage": dealstage,
      "description": quote["Description"],
      "quote_type": quote["Type"],
      "simpro_status": quote["Status"]["Name"],
      "closed_lost_reason": lost_reason,
      "salesperson": salesperson,
      
      # NEW: Basic Information
      "simpro_quote_name": (quote["Name"] rescue nil),
      "simpro_notes": (quote["Notes"] rescue nil),
      "simpro_order_no": (quote["OrderNo"] rescue nil),
      "simpro_request_no": (quote["RequestNo"] rescue nil),
      
      # NEW: Status & Stage
      "simpro_stage": (quote["Stage"] rescue nil),
      "simpro_customer_stage": (quote["CustomerStage"] rescue nil),
      "simpro_status_id": (quote["Status"]["ID"]&.to_s rescue nil),
      "simpro_status_color": (quote["Status"]["Color"] rescue nil),
      "simpro_is_closed": (quote["IsClosed"]&.to_s rescue nil),
      "simpro_auto_adjust_status": (quote["AutoAdjustStatus"]&.to_s rescue nil),
      
      # NEW: People
      "simpro_project_manager": (quote["ProjectManager"]["Name"] rescue nil),
      
      # NEW: Customer & Site
      "simpro_customer_id": (quote["Customer"]["ID"]&.to_s rescue nil),
      "simpro_customer_company_name": (quote["Customer"]["CompanyName"] rescue nil),
      "simpro_customer_given_name": (quote["Customer"]["GivenName"] rescue nil),
      "simpro_customer_family_name": (quote["Customer"]["FamilyName"] rescue nil),
      "simpro_site_id": (quote["Site"]["ID"]&.to_s rescue nil),
      "simpro_site_name": (quote["Site"]["Name"] rescue nil),
      
      # NEW: Dates
      "simpro_date_approved": (format_date_to_midnight(quote["DateApproved"]) rescue nil),
      "simpro_due_date": (format_date_to_midnight(quote["DueDate"]) rescue nil),
      "simpro_date_modified": (format_datetime(quote["DateModified"]) rescue nil),
      "simpro_validity_days": (quote["ValidityDays"] rescue nil),
      
      # NEW: Financial Details
      "simpro_total_tax": (quote["Total"]["Tax"] rescue nil),
      "simpro_total_inc_tax": (quote["Total"]["IncTax"] rescue nil),
      "simpro_materials_cost_estimate": (quote["Totals"]["MaterialsCost"]["Estimate"] rescue nil),
      "simpro_materials_cost_revised": (quote["Totals"]["MaterialsCost"]["Revised"] rescue nil),
      "simpro_materials_markup_estimate": (quote["Totals"]["MaterialsMarkup"]["Estimate"] rescue nil),
      "simpro_resources_cost_total": (quote["Totals"]["ResourcesCost"]["Total"]["Estimate"] rescue nil),
      "simpro_resources_cost_labor": (quote["Totals"]["ResourcesCost"]["Labor"]["Estimate"] rescue nil),
      "simpro_labor_hours_estimate": (quote["Totals"]["ResourcesCost"]["LaborHours"]["Estimate"] rescue nil),
      "simpro_plant_equipment_cost": (quote["Totals"]["ResourcesCost"]["PlantAndEquipment"]["Estimate"] rescue nil),
      "simpro_commission_estimate": (quote["Totals"]["ResourcesCost"]["Commission"]["Estimate"] rescue nil),
      "simpro_overhead_estimate": (quote["Totals"]["ResourcesCost"]["Overhead"]["Estimate"] rescue nil),
      "simpro_resources_markup_total": (quote["Totals"]["ResourcesMarkup"]["Total"]["Estimate"] rescue nil),
      "simpro_resources_markup_labor": (quote["Totals"]["ResourcesMarkup"]["Labor"]["Estimate"] rescue nil),
      "simpro_adjusted_estimate": (quote["Totals"]["Adjusted"]["Estimate"] rescue nil),
      "simpro_membership_discount": (quote["Totals"]["MembershipDiscount"] rescue nil),
      "simpro_discount": (quote["Totals"]["Discount"] rescue nil),
      
      # NEW: Certificates
      "simpro_stcs": (quote["Totals"]["STCs"] rescue nil),
      "simpro_veecs": (quote["Totals"]["VEECs"] rescue nil),
      "simpro_stc_eligible": (quote["STC"]["STCsEligible"]&.to_s rescue nil),
      "simpro_veec_eligible": (quote["STC"]["VEECsEligible"]&.to_s rescue nil),
      "simpro_stc_value": (quote["STC"]["STCValue"] rescue nil),
      "simpro_veec_value": (quote["STC"]["VEECValue"] rescue nil),
      
      # NEW: Calculated Pricing Fields
      "simpro_net_price_inc_tax": net_price_inc_tax,
      "simpro_discount_amount_inc_tax": discount_amount_inc_tax,
      "simpro_final_total_after_stcs": final_total_after_stcs,
      
      # NEW: Job Related
      "simpro_converted_from_lead": (quote["ConvertedFromLead"]["ID"]&.to_s rescue nil),
      "simpro_job_no": (quote["JobNo"] rescue nil),
      "simpro_is_variation": (quote["IsVariation"]&.to_s rescue nil),
      "simpro_linked_job_id": (quote["LinkedJobID"] rescue nil),
      
      # NEW: Forecast
      "simpro_forecast_year": (quote["Forecast"]["Year"] rescue nil),
      "simpro_forecast_month": (quote["Forecast"]["Month"] rescue nil),
      "simpro_forecast_percent": (quote["Forecast"]["Percent"] rescue nil)
    }
    
    # Remove nil values but keep empty strings and zeros
    properties.delete_if { |k, v| v.nil? }
    
    # Convert symbol keys to strings for HubSpot API
    properties_stringified = properties.transform_keys(&:to_s)
    
    body_json = { "properties" => properties_stringified }
    
    # Debug: log what we're sending
    puts "📤 Updating deal #{deal_id} with #{properties_stringified.keys.count} properties"
    puts "   New simPRO properties: #{properties_stringified.keys.select { |k| k.start_with?('simpro_') }.count}"

      if deal_id.present?
       response = HTTParty.patch("#{DEAL_PATH}/#{deal_id}",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
       if response.present? && response.success?
         puts "✅ Deal updated #{deal_name} #{quote["DateIssued"]}"
       else
         puts "❌ Deal update failed: #{response.code} - #{response.body[0..200]}"
       end
      end

      if response.present? && response.success?

        contact = HTTParty.get("https://api.hubapi.com/crm/v4/objects/leads/#{lead_id}/associations/contacts",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        contact_id = contact["results"].first["toObjectId"] rescue nil
        company = HTTParty.get("https://api.hubapi.com/crm/v4/objects/leads/#{lead_id}/associations/companies",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        company_id = company["results"].first["toObjectId"] rescue nil
        if contact_id.present?
          site = HTTParty.get("https://api.hubapi.com/crm/v4/objects/contacts/#{contact_id}/associations/p_sites",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
          site_id = site["results"].first["toObjectId"] rescue nil
        end
        if contact_id.present?
          ass_response = HTTParty.put("https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}/associations/contacts/#{contact_id}/deal_to_contact",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        end
        if company_id.present?
          ass_response = HTTParty.put("https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}/associations/companies/#{company_id}/deal_to_company",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        end
        if site_id.present?
          
          ass_response = HTTParty.put("https://api.hubapi.com/crm/v3/objects/deals/#{deal_id.to_i}/associations/p_sites/#{site_id}/109?paginateAssociations=false",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        end
        Hubspot::Quote.update_quote(quote,timeline_data,existing_deal)
      end


  end


    def self.update_properties(deal_id,quote,time)

      sync_time = (time.round(2)).to_s + " seconds"
        body_json = {
        "properties": {
          "amount":  quote["Total"]["ExTax"],
          "last_synced": Time.strptime(Time.now.to_datetime.strftime("%m/%d/%Y %I:%M %p"), "%m/%d/%Y %I:%M %p").to_i * 1000,
          "sync_time": sync_time
        }
      }

      response = HTTParty.patch("#{DEAL_PATH}/#{deal_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
    end

    def self.update_quote_id(deal_id,quote_id)
      body_json = {
        "properties": {
          "simpro_quote_id": quote_id,
        }
      }

      response = HTTParty.patch("#{DEAL_PATH}/#{deal_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
    end

    def self.attach_site(site_id,deal_id)
      site = Hubspot::Site.search_site(site_id)
      sm_site_id = site["results"].first["id"] rescue nil
      if sm_site_id.present?
        response = HTTParty.put("https://api.hubapi.com/crm/v3/objects/deals/#{deal_id}/associations/p_sites/#{sm_site_id.to_i}/54?paginateAssociations=false",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      end
    end

    def self.find_deal(simpro_id)
      sleep(1)
       body_json =
          {
        "properties": ["amount", "dealstage", "hs_object_id", "createdAt", "hubspot_lead_id","pipeline"],
        "filterGroups":[
          {
            "filters":[
              {
                "propertyName": "simpro_quote_id",
                "operator": "EQ",
                "value": "#{simpro_id}"
              }
            ]
          }
        ]
      }
      response = HTTParty.post("#{DEAL_PATH}/search",:body=> body_json.to_json, :headers => {
           "Content-Type" => "application/json","Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
         })
      return response
    end
    
    # Helper method to format date to midnight UTC (for date fields)
    def self.format_date_to_midnight(date_value)
      return nil if date_value.nil? || date_value.to_s.empty?
      
      begin
        # Parse date and set to midnight UTC explicitly
        parsed_date = Date.parse(date_value.to_s)
        # Convert to Time in UTC at midnight
        midnight_utc = Time.utc(parsed_date.year, parsed_date.month, parsed_date.day, 0, 0, 0)
        midnight_utc.to_i * 1000 # Convert to milliseconds
      rescue => e
        puts "⚠️  Error formatting date '#{date_value}': #{e.message}"
        nil
      end
    end
    
    # Helper method to format datetime (for datetime fields)
    def self.format_datetime(datetime_value)
      return nil if datetime_value.nil? || datetime_value.to_s.empty?
      
      begin
        # Parse datetime and convert to milliseconds
        if datetime_value.is_a?(String)
          parsed_time = Time.parse(datetime_value)
        elsif datetime_value.is_a?(Integer)
          parsed_time = Time.at(datetime_value)
        else
          parsed_time = datetime_value.to_time
        end
        parsed_time.to_i * 1000 # Convert to milliseconds
      rescue => e
        puts "⚠️  Error formatting datetime '#{datetime_value}': #{e.message}"
        nil
      end
    end
    
    # Helper method to calculate Net Price (Inc Tax) from primary line items
    # This sums all line item totals before quote-level discounts/adjustments
    def self.calculate_net_price_inc_tax(quote)
      net_price = 0
      
      return 0 unless quote && quote["Sections"] && quote["Sections"].any?
      
      quote["Sections"].each do |section|
        next unless section && section["CostCenters"] && section["CostCenters"].any?
        
        section["CostCenters"].each do |cc|
          # Only include primary cost centers (skip optional)
          next if cc["OptionalDepartment"]
          
          items = cc["Items"]
          next unless items
          
          # Sum all item types
          ["Catalogs", "OneOffs", "Prebuilds", "ServiceFees", "Labors"].each do |item_type|
            next unless items[item_type] && items[item_type].any?
            
            items[item_type].each do |item|
              line_total_inc = item["Total"]["Amount"]["IncTax"] rescue 0
              net_price += line_total_inc
            end
          end
        end
      end
      
      net_price.round(2)
    rescue => e
      puts "⚠️  Error calculating net price inc tax: #{e.message}"
      0
    end


  end
end