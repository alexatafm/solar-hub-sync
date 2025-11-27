  class HubspotController < ApplicationController
    skip_before_action :verify_authenticity_token

    def lead_webhook

      customer_type = params["properties"]["customer_type"]["value"]

      

      #contact details

      contact = HTTParty.get("https://api.hubapi.com/crm/v4/objects/leads/#{params["properties"]["hs_object_id"]["value"]}/associations/contacts",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      contact_id = contact["results"].first["toObjectId"]

      contact_details = HTTParty.get("https://api.hubapi.com/crm/v4/objects/contacts/#{contact_id}?properties=salutation,firstname,lastname,email,phone,mobilephone,address,city,state,zip,simpro_customer_id,assigned_consultant,territory,time_slot_of_booking,date_of_booking,is_there_anything_else_you_would_like_to_tell_us_,hs_state_code",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      Simpro::Customer.create_update_customer(contact_details)
      customer_email = CGI.escape(contact_details["properties"]["email"])
      customer = Simpro::Customer.find_customer(customer_email)
      customer_id = customer.first["ID"] rescue nil
      customer_id = [customer_id] if customer_id.present?




      if customer_type == "commercial"
        company = HTTParty.get("https://api.hubapi.com/crm/v4/objects/leads/#{params["properties"]["hs_object_id"]["value"]}/associations/companies",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        company_id = company["results"].first["toObjectId"]
        company_details = HTTParty.get("https://api.hubapi.com/crm/v4/objects/companies/#{company_id}?properties=name,phone,email,website,address,city,state,zip,simpro_customer_id",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
       Simpro::Company.create_update_company(company_details)
       company = Simpro::Company.find_company(company_details["properties"]["name"])
       customer_id = company.first["ID"] rescue nil
       customer_id = [customer_id] if customer_id.present?
      end


      #site details
      street_address = params["properties"]["street_address"]["value"]
      suburb = params["properties"]["suburb"]["value"]
      state = params["properties"]["state"]["value"]
      postcode = params["properties"]["post_code"]["value"]

      Simpro::Site.create_update_site(street_address,suburb,state,postcode,customer_id,params["properties"],contact_details)

      head :ok
    end

    def create_hs_record
      Rails.logger.info "========== create_hs_record STARTED =========="
      
      begin
        contact_id = params["properties"]["hs_object_id"]["value"]
        Rails.logger.info "Contact ID: #{contact_id}"
        
        contact_details = HTTParty.get("https://api.hubapi.com/crm/v4/objects/contacts/#{contact_id}?properties=salutation,firstname,lastname,email,phone,mobilephone,address,city,state,zip,simpro_customer_id,assigned_consultant,territory,time_slot_of_booking,date_of_booking,is_there_anything_else_you_would_like_to_tell_us_,customer_type,unit_number,hs_state_code,interested_solutions,provide_additional_information,power_bills,concession_card,concession_card_details,actewagl_or_agl_account_holder,how_did_you_hear_about_solarhub_,company",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        Rails.logger.info "Contact details fetched: #{contact_details.present?}"
        
        # Create/Update Lead
        lead_response = Hubspot::Lead.create_update_lead(contact_id,contact_details)
        Rails.logger.info "Lead Response: #{lead_response.inspect}"
        
        if lead_response.present?
          if lead_response.success?
            Rails.logger.info "✅ Lead created successfully: #{lead_response['id']}"
          else
            Rails.logger.error "❌ Lead creation failed: #{lead_response.code} - #{lead_response.body}"
          end
        else
          Rails.logger.error "❌ Lead response is nil"
        end
        
        # Handle Company
        if contact_details["properties"]["company"].present?
          company =  Hubspot::Company.find_company(contact_details["properties"]["company"])
          if company["results"].present?
            company_id = company["results"].first["id"]
            Hubspot::Contact.associate_company(company_id,contact_id)
            Rails.logger.info "✅ Associated existing company: #{company_id}"
          else
            company_response = Hubspot::Company.create_company(contact_details["properties"]["company"])
            if company_response.present? && company_response.success?
              company_id = company_response["id"]
              Hubspot::Contact.associate_company(company_id,contact_id)
              Rails.logger.info "✅ Created and associated new company: #{company_id}"
            else
              Rails.logger.error "❌ Company creation failed: #{company_response.inspect}"
            end
          end
        end
        
        # Associate Lead with Contact and Company
        if lead_response.present? && lead_response.success? 
          Hubspot::Lead.associate_contact(contact_id,lead_response["id"])
          Rails.logger.info "✅ Associated Lead with Contact"
          
          if defined?(company_response) && company_response.present? && company_response.success?
            Hubspot::Lead.associate_company(company_id,lead_response["id"])
            Rails.logger.info "✅ Associated Lead with Company"
          end
        end
        
        # Create Site
        site_response = Hubspot::Site.create_update_site(contact_details)
        Rails.logger.info "Site Response: #{site_response.inspect}"
        
        if site_response.present? && site_response.success?
          Hubspot::Site.associate_contact(contact_id,site_response["id"])
          Rails.logger.info "✅ Site created and associated: #{site_response['id']}"
        else
          Rails.logger.error "❌ Site creation failed: #{site_response.inspect}"
        end
        
        Rails.logger.info "========== create_hs_record COMPLETED =========="
        
      rescue => e
        Rails.logger.error "========== create_hs_record ERROR =========="
        Rails.logger.error "Error: #{e.message}"
        Rails.logger.error "Backtrace: #{e.backtrace.first(10).join("\n")}"
        Rails.logger.error "=========================================="
      end
      
      head :ok
    end

    def create_ticket_job
      simpro_job_id = params["properties"]["simpro_job_id"]["value"] rescue nil
      contact = HTTParty.get("https://api.hubapi.com/crm/v4/objects/p_jobs/#{params["properties"]["hs_object_id"]["value"]}/associations/contacts",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      contact_id = contact["results"].first["toObjectId"] rescue nil
      if contact_id.present?
        contact_details = HTTParty.get("https://api.hubapi.com/crm/v4/objects/contacts/#{contact_id}?properties=salutation,firstname,lastname,email,phone,mobilephone,address,city,state,zip,simpro_customer_id,assigned_consultant,territory,time_slot_of_booking,date_of_booking,is_there_anything_else_you_would_like_to_tell_us_",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        customer = Simpro::Customer.find_customer(contact_details["properties"]["email"])
        customer_id = customer.first["ID"] rescue nil
        customer_id = [customer_id] if customer_id.present?
        salesperson = Simpro::Customer.find_sales_person(contact_details["properties"]["assigned_consultant"]) rescue nil
        if salesperson.present?
          sales_id = salesperson.first["ID"]
        else
          sales_id = nil
        end
      end

      company = HTTParty.get("https://api.hubapi.com/crm/v4/objects/p_jobs/#{params["properties"]["hs_object_id"]["value"]}/associations/companies",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      company_id = company["results"].first["toObjectId"] rescue nil
      if company_id.present?
        company_details = HTTParty.get("https://api.hubapi.com/crm/v4/objects/companies/#{company_id}?properties=name,phone,email,website,address,city,state,zip,simpro_customer_id",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        company = Simpro::Company.find_company(company_details["properties"]["name"])
        customer_id = company.first["ID"] rescue nil
        customer_id = [customer_id] if customer_id.present?
      end

      site = HTTParty.get("https://api.hubapi.com/crm/v4/objects/p_jobs/#{params["properties"]["hs_object_id"]["value"]}/associations/p_sites",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      site_id = site["results"].first["toObjectId"] rescue nil
      if site_id.present?
        site_details = HTTParty.get("https://api.hubapi.com/crm/v4/objects/p_sites/#{site_id}?properties=site,phone,email,website,address,city,state,zip,simpro_customer_id,street_address",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        site = Simpro::Site.get_site(site_details["properties"]["site"])
        site_id = site.first["ID"] rescue nil
        site_id = [site_id] if site_id.present?
      end


      if simpro_job_id.blank?
        Simpro::Job.create_update_ticket_job(params["properties"],customer_id,site_id)
      end
    end

    def contact_webhook

      simpro_customer_id = params["properties"]["simpro_customer_id"]["value"] rescue nil
      if simpro_customer_id.blank?
        contact_id = params["properties"]["hs_object_id"]["value"]
        contact_details = HTTParty.get("https://api.hubapi.com/crm/v4/objects/contacts/#{contact_id}?properties=salutation,firstname,lastname,email,phone,mobilephone,address,city,state,hs_state_code,zip,country,simpro_customer_id,assigned_consultant,territory,time_slot_of_booking,date_of_booking,is_there_anything_else_you_would_like_to_tell_us_",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      Simpro::Customer.create_update_customer(contact_details)
      end
    end

    def create_job
      simpro_job_id = params["properties"]["simpro_job_id"]["value"] rescue nil
      contact = HTTParty.get("https://api.hubapi.com/crm/v4/objects/p_jobs/#{params["properties"]["hs_object_id"]["value"]}/associations/contacts",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      contact_id = contact["results"].first["toObjectId"] rescue nil
      if contact_id.present?
        contact_details = HTTParty.get("https://api.hubapi.com/crm/v4/objects/contacts/#{contact_id}?properties=salutation,firstname,lastname,email,phone,mobilephone,address,city,state,zip,simpro_customer_id,assigned_consultant,territory,time_slot_of_booking,date_of_booking,is_there_anything_else_you_would_like_to_tell_us_",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        customer = Simpro::Customer.find_customer(contact_details["properties"]["email"])
        customer_id = customer.first["ID"] rescue nil
        customer_id = [customer_id] if customer_id.present?
        salesperson = Simpro::Customer.find_sales_person(contact_details["properties"]["assigned_consultant"]) rescue nil
        if salesperson.present?
          sales_id = salesperson.first["ID"]
        else
          sales_id = nil
        end
      end

      company = HTTParty.get("https://api.hubapi.com/crm/v4/objects/p_jobs/#{params["properties"]["hs_object_id"]["value"]}/associations/companies",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      company_id = company["results"].first["toObjectId"] rescue nil
      if company_id.present?
        company_details = HTTParty.get("https://api.hubapi.com/crm/v4/objects/companies/#{company_id}?properties=name,phone,email,website,address,city,state,zip,simpro_customer_id",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        company = Simpro::Company.find_company(company_details["properties"]["name"])
        customer_id = company.first["ID"] rescue nil
        customer_id = [customer_id] if customer_id.present?
      end

      site = HTTParty.get("https://api.hubapi.com/crm/v4/objects/p_jobs/#{params["properties"]["hs_object_id"]["value"]}/associations/p_sites",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      site_id = site["results"].first["toObjectId"] rescue nil
      if site_id.present?
        site_details = HTTParty.get("https://api.hubapi.com/crm/v4/objects/p_sites/#{site_id}?properties=site,phone,email,website,address,city,state,zip,simpro_customer_id,street_address",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        site = Simpro::Site.get_site(site_details["properties"]["site"])
        site_id = site.first["ID"] rescue nil
        site_id = [site_id] if site_id.present?
      end


      if simpro_job_id.blank?
        Simpro::Job.create_job(params["properties"],customer_id,site_id,sales_id)
      end
    end

    def site_visit_incomplete_webhook
      simpro_quote_id = params["properties"]["simpro_quote_id"]["value"]
      if simpro_quote_id.present?
        Simpro::Quote.site_visit_incomplete(simpro_quote_id)
      end
    end

    def create_support_quote
      # ProcessHubspotQuoteJob.delay(run_at: 1.seconds.from_now).perform(params)
      puts  "---------create quote from hubspot---------------------"
      Simpro::Quote.create_support_quote(params)
    end

    def disqualify_webhook
      simpro_quote_id = params["properties"]["simpro_quote_id"]["value"]
      if simpro_quote_id.present?
        Simpro::Quote.disqualify(simpro_quote_id)
      end
    end
  end
