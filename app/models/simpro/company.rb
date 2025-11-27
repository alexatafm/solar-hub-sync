module Simpro
  # Simpro company OBJECT

  class Company

    def self.webhook_customer(customer_id)
      query = { 
        "columns"     => "ID,CompanyName,Phone,DoNotCall,AltPhone,Banking,Address,BillingAddress,CustomerType,Email,Fax,PreferredTechs,EIN,Website,Contacts,Profile,Sites",
        "pageSize"      => 1
       }

      response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/customers/companies/#{customer_id}",:query=> query, :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })

      if response["errors"].present?
        
        response = Simpro::Customer.webhook_individual_customer(customer_id)
      end

        # @response = response
      unless response.blank?
        company_response = Hubspot::Company.create(response)
      end    
    end


    def self.attach_contact(customer,company_id)
        query = { 
            "columns"     => "ID,Email,GivenName,FamilyName,WorkPhone,CellPhone,AltPhone",
            "search" => "any"
           }
        allcontact =  HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/contacts/?Email=#{customer["properties"]["email"]}", :headers => {
            "Content-Type" => "application/json",
             "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
          }) rescue nil
        company_contacts = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/customers/#{company_id}/contacts/",:query=> query, :headers => {
            "Content-Type" => "application/json",
             "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
          })
        emails = company_contacts.map{|i| i["Email"]}
        
        # Get phone numbers for matching
        customer_phone = customer["properties"] && customer["properties"]["phone"]
        customer_mobile = customer["properties"] && customer["properties"]["mobilephone"]
        
           body_json = {
            "Title" => customer["properties"] && customer["properties"]["salutation"] || "",
            "GivenName" => customer["properties"] && customer["properties"]["firstname"] || "",
            "FamilyName" => customer["properties"] && customer["properties"]["lastname"] || "",
            "Email" => customer["properties"] && customer["properties"]["email"] || "",
            "Position" => customer["properties"] && customer["properties"]["jobtitle"] || "",
            "WorkPhone" => customer["properties"] && customer["properties"]["mobilephone"] || "",
            "Fax" => customer["properties"] && customer["properties"]["fax"] || "",
            "CellPhone" => customer["properties"] && customer["properties"]["mobilephone"] || "",
            "QuoteContact" => true,
            "PrimaryQuoteContact" => true
          }


        if emails.include?(customer["properties"]["email"]) 
          company_contact_id =  company_contacts.select{|i| i["Email"] == customer["properties"]["email"]}.first["ID"] rescue nil
        # If email doesn't match, try phone number matching
        elsif customer_mobile.present? || customer_phone.present?
          matched_contact = PhoneHelper.find_customer_by_phone(customer_mobile || customer_phone, company_contacts)
          company_contact_id = matched_contact["ID"] if matched_contact.present?
          if company_contact_id.present?
            response = HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/customers/#{company_id}/contacts/#{company_contact_id}",:body=> body_json.to_json, :headers => {
            "Content-Type" => "application/json",
             "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
          }) 
          end
        elsif allcontact.present?
          company_contact_id =  allcontact.first["ID"] rescue nil
          if company_contact_id.present?
            response = HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/customers/#{company_id}/contacts/#{company_contact_id}",:body=> body_json.to_json, :headers => {
            "Content-Type" => "application/json",
             "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
          })
          end 
        else
          response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/customers/#{company_id}/contacts/",:body=> body_json.to_json, :headers => {
            "Content-Type" => "application/json",
             "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
          }) 
        end
    end


    def self.find_hubspot_company(company,company_id)
      companyname = company["name"]["value"]

      if company["simpro_customer_id"].blank?
        companyname = companyname.gsub('&','%26') if companyname.include?('&')
        companyname = companyname.gsub('-','%2D') if companyname.include?('-')
        companyname = companyname.gsub('–','%96') if companyname.include?('–')
        companyname = companyname.gsub('—','%97') if companyname.include?('—')

        customer = Simpro::Company.find_company(companyname)
        if customer.present? && customer.success?
          response = Simpro::Company.create_update_company(company,company_id,customer.first["ID"])
        else
          response = Simpro::Company.create_update_company(company,company_id,nil)
        end
      else
        response = Simpro::Company.create_update_company(company,company_id,company["simpro_customer_id"])
      end

    end

    # def self.create_update_company(company,company_id,simpro_company_id)

    #   phone = company['phone'].present? && company['phone'].is_a?(String) ? company['phone'] : company.dig('phone', 'value') || "-"
    #   address = company['address'].present? && company['address'].is_a?(String) ? company['address'] : company.dig('address', 'value') || "-"
    #   city = company['city'].present? && company['city'].is_a?(String) ? company['city'] : company.dig('city', 'value') || "-"
    #   state = company['state'].present? && company['state'].is_a?(String) ? company['state'] : company.dig('state', 'value') || "-"
    #   zip = company['zip'].present? && company['zip'].is_a?(String) ? company['zip'] : company.dig('zip', 'value') || "-"
    #   country = company['country'].present? && company['country'].is_a?(String) ? company['country'] : company.dig('country', 'value') || "-"
    #   company_name = company['name'].present? && company['name'].is_a?(String) ? company['name'] : company.dig('name', 'value') || "-"



    #   body_json = {
    #     "CompanyName": company_name,
    #     "Phone": phone,
    #    "CustomerType": 'Customer',
    #     "Address": {
    #      "Address": address,
    #      "City": city,
    #      "State": state,
    #      "PostalCode": zip,
    #      "Country": country
    #     }
    #     }
    #   if simpro_company_id.present? && simpro_company_id["value"].present?
    #     simpro_company_id = simpro_company_id["value"] || simpro_company_id
    #     response = HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/customers/companies/#{simpro_company_id}",:body=> body_json.to_json, :headers => {
    #         "Content-Type" => "application/json",
    #          "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
    #         }) 

    #   else
    #     response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/customers/companies/",:body=> body_json.to_json, :headers => {
    #       "Content-Type" => "application/json",
    #        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
    #       }) 
    #     if response.present? && response.success?
    #       Hubspot::Company.update_simpro_id(response["ID"],company_id)
    #     end 
    #   end 
    #   return response

    # end
    def self.create_update_company(company_details)
      company = company_details["properties"]
      company_id = company_details["simpro_customer_id"]
      if company_id.blank?
        sm_company = Simpro::Company.find_company(company["name"])
        company_id = sm_company.first["ID"] rescue nil
      end
      body_json = {
        "CompanyName": company["name"],
        "Phone": company["phone"],
        "CustomerType": 'Lead',
        "Address": {
          "Address": company["address"],
          "City": company["city"],
          "State": company["state"],
          "PostalCode": company["zip"],
          "Country": company["country"]
        }
      }
      if company_id.present?
        response = HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/customers/companies/#{company_id}",:body=> body_json.to_json, :headers => {
          "Content-Type" => "application/json",
           "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        }) 
        if response.present? && response.success?
          Hubspot::Company.update_simpro_id(company_id,company_details["id"])
        end
      else
        response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/customers/companies/",:body=> body_json.to_json, :headers => {
          "Content-Type" => "application/json",
           "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        }) 
        if response.present? && response.success?
          Hubspot::Company.update_simpro_id(response["ID"],company_details["id"])
        end
      end

    end

    def self.find_company(companyname)
      companyname = CGI.escape(companyname)
       response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/customers/companies/?CompanyName=#{companyname}", :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
       })
    end
  end
end