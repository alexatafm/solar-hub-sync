  module Hubspot
  #
  # HubSpot CONTACT OBJECT
  #
  class Contact
    CONTACT_PATH='https://api.hubapi.com/crm/v3/objects/contacts'
    CRM_PATH = 'https://api.hubapi.com/crm/v3/objects/companies'

    # def self.create_update_individual(customer)
    #   # Method : Post
    #   # Example URL to POST to:
    #   time = Time.now.strftime("%m/%d/%Y %I:%M %p")
    #   if customer["ID"].present?
    #     existing_user = Hubspot::Contact.find_user(customer["ID"])
    #     if existing_user["results"].blank?
    #       existing_user = Hubspot::Contact.find_by_email(customer["Email"])
    #     end
    #   end 
    #   # cost_center = customer["Profile"]["ServiceJobCostCenter"]["Name"]  rescue ""
    #   create_date = (customer["DateCreated"].to_date) rescue (Date.today)
    #   body_json = {
    #     "properties": {
    #       "salutation": customer["Title"], 
    #        "phone": customer["Phone"].gsub(/[^0-9A-Za-z , : ]/, '') || '',
    #        "email": customer["Email"],
    #        "mobilephone": customer["CellPhone"] || '',
    #        "website": customer["Website"] || "",
    #        "fax": customer["Fax"] || "",
    #       "firstname": customer["GivenName"],
    #       "lastname": customer["FamilyName"],
    #       "address": customer["Address"]["Address"].gsub(/[^0-9A-Za-z , : ]/, '') || '',
    #       "city": customer["Address"]["City"],
    #       "state": customer["Address"]["State"],
    #       "zip": customer["Address"]["PostalCode"],
    #       "country": customer["Address"]["Country"],
    #       "postal_street_address": customer["BillingAddress"]["Address"],
    #       "postal_suburb": customer["BillingAddress"]["City"],
    #       "postal_state": customer["BillingAddress"]["State"],
    #       "postal_post_code": customer["BillingAddress"]["PostalCode"],
    #       "postal_country": customer["BillingAddress"]["Country"],
    #       "simpro_date_created": create_date,
    #      "simpro_contact_id": customer["ID"],
    #     }
    #   }
    #   if existing_user["results"].blank?
    #     response = HTTParty.post("#{CONTACT_PATH}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
    #   else  
    #     contact_id = existing_user["results"].first["id"]
    #     response = HTTParty.patch("#{CONTACT_PATH}/#{contact_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
    #     if response.present? && response.success?
          
    #     elsif response["message"].include?("A contact with the email")
    #       body_json[:properties].delete(:email)
    #       response = HTTParty.patch("#{CONTACT_PATH}/#{contact_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
    #     end
    #     if response.present? && response.success? && customer["Sites"].present?
    #       Hubspot::Site.associate_sites_customer(customer["Sites"],'individual',response["id"])
    #       puts "conatct added/updated #{customer["Email"]}" 
    #     end
    #   end
    # end

    def self.associate_company(company_id,contact_id)
     body_json =   [
        {
          "associationCategory": "HUBSPOT_DEFINED",
          "associationTypeId": 1
        }
    ]
    response = HTTParty.put("https://api.hubapi.com/crm/v4/objects/contact/#{contact_id.to_i}/associations/company/#{company_id.to_i}",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
         
    end

    def self.update_simpro_id(simpro_id,contact_id)
      body_json = {
        "properties": {
          "simpro_customer_id": simpro_id
        }
      }
      response = HTTParty.patch("#{CONTACT_PATH}/#{contact_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
    end
  end


end