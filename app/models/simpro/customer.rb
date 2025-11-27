module Simpro
  # Simpro customer OBJECT

  class Customer
   

    def self.find_hubspot_customer(contact,contact_id)
      email =  contact["email"]["value"] rescue nil
      firstname = contact["firstname"]["value"] rescue nil
      lastname = contact["lastname"]["value"] rescue nil
      if email.present?
        customer = Simpro::Customer.find_customer(email)
        if customer.blank?
          # customer =  Simpro::Customer.find_customer_name(firstname,lastname)
          if customer.blank?
            response = Simpro::Customer.create_update_customer(contact,contact_id,nil)
          else
            Simpro::Customer.create_update_customer(contact,contact_id,customer.first["ID"])
          end
        else
          if customer.present? && customer.success?
            Simpro::Customer.create_update_customer(contact,contact_id,customer.first["ID"])
            response = Simpro::Customer.find_customer(email)
          end
        end
        return response
      elsif contact["simpro_customer_id"].present? && contact["simpro_customer_id"]["value"].present?  && email.blank?
        response = Simpro::Customer.create_update_customer(contact,contact_id,contact["simpro_customer_id"]["value"])
      elsif contact["simpro_customer_id"].blank? && email.blank?
        response = Simpro::Customer.create_update_customer(contact,contact_id,nil)
      end
    end



    def self.create_update_customer(customer_detail)
      contact = customer_detail["properties"]
      body_json = {
        "Title": contact["salutation"],
        "GivenName": contact["firstname"],
        "FamilyName": contact["lastname"],
        "Phone": contact["phone"],
        "AltPhone": contact["mobilephone"],
        "CellPhone": contact["mobilephone"],  # Added for consistency with quote/site contacts
        "CustomerType": 'Lead',
        "Email": contact["email"],
        "Address": {
          "Address": contact["address"],
          "City": contact["city"],
          "State": contact["hs_state_code"],
          "PostalCode": contact["zip"],
          "Country": contact["country"]
        }
      }
      customer_id = customer_detail["properties"]["simpro_customer_id"]
      if customer_id.blank?
        customer_id = customer_detail["simpro_customer_id"]
      end
      if customer_id.blank?
        customer_email = CGI.escape(contact["email"])
        customer = Simpro::Customer.find_customer(customer_email)
        customer_id = customer.first["ID"] rescue nil
      end
      if customer_id.present?
        response = HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/customers/individuals/#{customer_id}",:body=> body_json.to_json, :headers => {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
        if response.present? && response.success?
          Hubspot::Contact.update_simpro_id(customer_id,customer_detail["id"])
        end

      else

        response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/customers/individuals/",:body=> body_json.to_json, :headers => {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
        if response.present? && response.success?
          Hubspot::Contact.update_simpro_id(response["ID"],customer_detail["id"])
        end
      end
      return response["ID"]
    end

    def self.create_quote_contact(body_json)
      response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/customers/individuals/",:body=> body_json.to_json, :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })

      if response.present? && response.success?
        return response["ID"]
      end 
    end

    def self.webhook_individual_customer(customer_id)
      #/api/v1.0/companies/{companyID}/contacts/
       
      query = { 
        "columns"     => "ID,GivenName,Title,FamilyName,Phone,DoNotCall,AltPhone,Address,Banking,Sites,BillingAddress,CustomerType,Email,PreferredTechs,Profile,DateCreated,CellPhone",
        "pageSize"      => 1 
       }

      response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/customers/individuals/#{customer_id}",:query=> query, :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })
      unless response.blank?
        Hubspot::Contact.create_update_individual(response) 
      end
    end


    def self.find_customer(email)
    	query = { 
        "columns"     => "ID,Email",
        "search" => "any"
       }
       response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/customers/individuals/?Email=#{email}",:query=> query, :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
         })
      return response
    end


    def self.find_customer_name(firstname,lastname)
      response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/customers/individuals/?FamilyName=#{lastname}&GivenName=#{firstname}", :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
       })
      return response
    end

    def self.find_notes(customer_id)
      response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/customers/#{customer_id}/notes/", :headers => {
          "Content-Type" => "application/json",
           "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
    end
  end

end