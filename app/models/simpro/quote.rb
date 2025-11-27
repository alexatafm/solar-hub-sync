 module Simpro
  # Simpro customer OBJECT

  class Quote
    def self.create_support_quote(deal)

      deal_id = deal["properties"]["hs_object_id"]["value"]
      quote_id = deal["properties"]["simpro_quote_id"]["value"] rescue nil
      pipeline = deal["properties"]["pipeline"]["value"] rescue nil
      due_date = Time.at(deal["properties"]["closedate"]["timestamp"]/1000).to_date.strftime('%Y-%m-%d')


      unless quote_id.present?
        hs_site = HTTParty.get("https://api.hubapi.com/crm/v4/objects/deals/#{deal_id}/associations/p_sites",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        #site code
        if hs_site["results"].present?
          hs_site_id =  hs_site["results"].first["toObjectId"] rescue nil
          if hs_site_id.present?
            site_detail = HTTParty.get("https://api.hubapi.com/crm/v4/objects/p_sites/#{hs_site_id}?properties=site,simpro_site_id,site_address",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
          end
          if site_detail["properties"].present? && site_detail["properties"]["simpro_site_id"].present?
            site_id = site_detail["properties"]["simpro_site_id"]  
          end
        else
          site_name = site_detail["properties"]["site"]  rescue ""
          site_address = site_detail["properties"]["site_address"] rescue ""
          site_response = Simpro::Site.create_deal_site(site_name,site_address)
          if site_response.success?
            site_id = site_response["ID"]
          end
        end
        user_id = Hubspot::Deal.get_deal_associated_contact(deal_id) rescue nil
      
        company_id = Hubspot::Deal.get_deal_associated_company(deal_id) rescue nil


        #company/contact code
        
        
        if user_id.present?
          contact_details = HTTParty.get("https://api.hubapi.com/crm/v4/objects/contacts/#{user_id.first}?properties=salutation,firstname,lastname,email,phone,mobilephone,address,city,state,zip,simpro_customer_id,assigned_consultant,territory,time_slot_of_booking,date_of_booking,is_there_anything_else_you_would_like_to_tell_us_",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
          Simpro::Customer.create_update_customer(contact_details)
          customer = Simpro::Customer.find_customer(contact_details["properties"]["email"])
          customer_id = customer.first["ID"] rescue nil
          customer_id = [customer_id] if customer_id.present?
  
        elsif company_id.present?
          company_details = HTTParty.get("https://api.hubapi.com/crm/v4/objects/companies/#{company_id}?properties=name,phone,email,website,address,city,state,zip,simpro_customer_id",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
          Simpro::Company.create_update_company(company_details)
          company = Simpro::Company.find_company(company_details["properties"]["name"])
          customer_id = company.first["ID"] rescue nil
          customer_id = [customer_id] if customer_id.present?
        end
        if site_id.present? && customer_id.present?
          puts "site found"
          created_date = Time.at(deal["properties"]["createdate"]["timestamp"]/1000).to_date.strftime('%Y-%m-%d')
          description = deal["properties"]["description"]["value"] rescue "--"
          body_json = {
            "Customer": customer_id.first.to_i,
            "Site": site_id.to_i,
            "Description": description,
            "Type": "Service",
            "DateIssued": created_date,
            "Name": deal["properties"]["dealname"]["value"],
            "Stage": "InProgress",
            "Status": 382
            }


          quote_response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/quotes/",:body=> body_json.to_json, :headers => {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
          })
        end

        if quote_response.present? && quote_response.success?
          quote_id = quote_response["ID"]
          Hubspot::Deal.update_quote_id(deal_id,quote_id)
          Simpro::Quote.update_deal_id(deal_id,quote_id)
        end
        Hubspot::Deal.update_response(quote_response,deal_id)
      end
    end

    def self.create_quote(site_id,customer_id,quote_details,contact_details)
      salesperson = self.find_sales_person(contact_details["properties"]["assigned_consultant"])
      if salesperson.present?
        sales_id = salesperson.first["ID"]
      end
      description = contact_details["properties"]["is_there_anything_else_you_would_like_to_tell_us_"] rescue nil
      created_date = Time.at(quote_details["hs_createdate"]["value"].to_i/1000).to_date.strftime('%Y-%m-%d')
      body_json = {
          "Customer": customer_id.first,
          "Site": site_id,
          "Description": description,
          "Type": "Service",
          "DateIssued": created_date,
          "Name": quote_details["hs_lead_name"]["value"],
          "Stage": "InProgress",
          "Salesperson": sales_id,
          "Status": 382
          }


      quote_response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/quotes/",:body=> body_json.to_json, :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })

      if quote_response.present? && quote_response.success?
        quote_id = quote_response["ID"]
        Hubspot::Lead.update_quote_id(quote_id,quote_details["hs_object_id"]["value"])
        Simpro::Quote.update_lead_id(quote_details["hs_object_id"]["value"],quote_id)
      end

      cost_centers = quote_details["interested_solutions"]["value"].split(';')
      cost_centers.each_with_index do |cost_center,index|

        case cost_center
          when "solar-energy"
            cost_center_name = "Domestic Solar"
            cs_id = 2
          when "hot-water"
            cost_center_name = "Hot Water"
            cs_id = 5
          when "electric-vehicle-charging"
            cost_center_name = "EV Charging"
            cs_id = 139
          when "induction-cooktop"
            cost_center_name = "Induction Cooktops"
            cs_id = 140
          when "battery-storage"
            cost_center_name = "Domestic Solar & Batteries"
            cs_id = 9
          when "air-conditioning"
            cost_center_name = "Air Conditioning"
            cs_id = 106
        end
        section_response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/sections/", :headers => {
          "Content-Type" => "application/json",
            "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
          })

        if section_response.blank?
          body_json = {
            "DisplayOrder": 0,
          }
          section_response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/sections/",:body=> body_json.to_json, :headers => {
              "Content-Type" => "application/json",
                "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
            })
          section_id = section_response["ID"] rescue nil
        else
          section_id =  section_response.first["ID"] rescue nil
        end

        cost_body_json = {
          "Name": cost_center_name,
          "CostCenter": cs_id

        }
        cost_center_response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/sections/#{section_id}/costCenters/",:body=> cost_body_json.to_json, :headers => {
            "Content-Type" => "application/json",
              "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })

        if index == 0 && cost_center_response.present? && cost_center_response.success? && sales_id.present?
          date_of_booking = contact_details["properties"]["date_of_booking"] rescue nil
          time_slot = contact_details["properties"]["time_slot_of_booking"].split('-') rescue nil
          start_time = time_slot.first.strip
          end_time = time_slot.last.strip
          activity_body_json = {
            "Date": date_of_booking,
            "Staff": sales_id,
            "Blocks": [
              {
                "StartTime": start_time,
                "EndTime": end_time,
                "ScheduleRate": 1
              }
            ]
          }
          schedule_response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/sections/#{section_id}/costCenters/#{cost_center_response["ID"]}/schedules/",:body=> activity_body_json.to_json, :headers => {
            "Content-Type" => "application/json",
              "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
          })
          if schedule_response.present? && schedule_response.success?
            Hubspot::Lead.update_activity_id(schedule_response["ID"],quote_details["hs_object_id"]["value"])
          end
        end
      end
      #229 deal id
      #230 lead id
    end

    def self.create_quote_attachment(quote_id,data)
      simpro_attachments = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/attachments/files/", :headers => {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })
      file_names = simpro_attachments.map{|i| i["Filename"]} rescue []
      filename = data["name"] + ".#{data["extension"]}"
      if file_names.include?(filename)
        puts "file already exists"
      else
        file_type = data["extension"]
        file_url = data["url"]
        uri = URI(file_url)
        file_content = Net::HTTP.get(uri)
        encoded_file = Base64.strict_encode64(file_content)
        file_body_json = {
          "Filename": "#{filename}",
          "Public": true,
          "Base64Data": "#{encoded_file}"
        }
        file_response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/attachments/files/",:body=> file_body_json.to_json, :headers => {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
        if file_response.present? && file_response.success?
          puts "attachment created"
        end
      end
    end


    def self.change_to_newjob(quote_id,params)
      body_json = {
       "Status": 173
      }
      response =  HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}",:body=> body_json.to_json, :headers => {
          "Content-Type" => "application/json",
           "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
      # if response.present? && response.success?
      #   Hubspot::Job.create_update(params)
      # end
    end

    def self.site_visit_incomplete(quote_id)
      body_json = {
       "Status": 387
      }
      response =  HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}",:body=> body_json.to_json, :headers => {
          "Content-Type" => "application/json",
           "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
    end

    def self.disqualify(quote_id)
      body_json = {
       "IsClosed": true,
       "ArchiveReason": 2
      }
      response =  HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}",:body=> body_json.to_json, :headers => {
          "Content-Type" => "application/json",
           "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
    end



     def self.update_lead_id(lead_id,quote_id)

      body_json = {
       "Value": lead_id
      }
      response =  HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/customFields/230",:body=> body_json.to_json, :headers => {
          "Content-Type" => "application/json",
           "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
      
    end

    def self.update_deal_id(deal_id,quote_id)
      body_json = {
       "Value": deal_id
      }
      response =  HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/customFields/229",:body=> body_json.to_json, :headers => {
          "Content-Type" => "application/json",
           "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
        if response.present? && response.success?
          puts "deal id updated simpro"
        end
      
    end


    def self.webhook_quote(quote_id)
      query = { 
        "columns"     => "ID,Customer,Site,SiteContact,Description,Salesperson,ProjectManager,CustomerContact,Technician,DateIssued,DueDate,DateApproved,OrderNo,Name,Stage,Total,Totals,Status,Tags,Notes,Type,STC,LinkedJobID,ArchiveReason,CustomFields",
         "pageSize"      => 1 
       }

      response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}",:query=> query, :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })

      timeline_data =  HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/timelines/", :headers => {
            "Content-Type" => "application/json",
             "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
          })
      if response.present? && response.success?
        Hubspot::Deal.update_deal_value(response,timeline_data)
      end
    end

    # def self.all_quotes
    #   query = { 
    #     "columns"     => "ID,Customer,Site,SiteContact,Description,Salesperson,ProjectManager,CustomerContact,Technician,DateIssued,DueDate,DateApproved,OrderNo,Name,Stage,Total,Totals,Status,Tags,Notes,Type,STC,LinkedJobID,ArchiveReason",
    #      "pageSize"      => 250,
    #      "page" => 2
    #    }
    #   response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/",:query=> query, :headers => {
    #     "Content-Type" => "application/json",
    #      "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
    #   })
    #   response.each_with_index do |quote,index|
    #     puts "quote #{index}"
    #       self.webhook_quote(quote["ID"])
    #   end
    # end


    def self.find_sales_person(salesperson_name)
      query = { 
        "columns"     => "ID,Name",
        "search" => "any"
      }
     response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/staff/?Name=#{salesperson_name}",:query=> query, :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })
   end



    def self.sync_cost_center
     query = { 
         "columns"     => "ID,Name",
          "pageSize"      => 250,
          "page" => 1
       }
      cost_response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/setup/accounts/costCenters/?display=all",:query=> query, :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })
      cost_response.each_with_index do |cost_center_item,index|
            body_json = {
                "properties": {
                  "simpro_id": cost_center_item["ID"],
                  "name": cost_center_item["Name"]
                }
              }
            response = HTTParty.post("https://api.hubspot.com/crm/v3/objects/p_costcenters",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
 
      end
       
    end

  end
end