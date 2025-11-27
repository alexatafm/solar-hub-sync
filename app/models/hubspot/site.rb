module Hubspot  
  class Site
    SITE_PATH = 'https://api.hubapi.com/crm/v3/objects/p_sites'
    def self.update_simpro_id(simpro_site_id,site_name)
      site = Hubspot::Site.search_site_by_name(site_name)
      site_id = site["results"].first["id"]
      if site_id.present? && simpro_site_id.present?
        body_json = {
        "properties": {
         "simpro_site_id":  simpro_site_id
        }
        }
      response = HTTParty.patch("#{SITE_PATH}/#{site_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      end
    end


    def self.associate_sites_customer(sites,contact_type,contact_id)
      sites.each do |simpro_site|
        site = Hubspot::Site.search_site_by_name(simpro_site["Name"])
        if site["results"].present? && contact_id.present?
          site_id = site["results"].first["id"]
          if contact_type == "individual"
            ass_response = HTTParty.put("https://api.hubapi.com/crm/v3/objects/p_sites/#{site_id}/associations/contacts/#{contact_id.to_i}/82?paginateAssociations=false",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
          else
            ass_response = HTTParty.put("https://api.hubapi.com/crm/v3/objects/p_sites/#{site_id}/associations/companies/#{contact_id.to_i}/52?paginateAssociations=false",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
          end
        end
      end
    end



    def self.create_site(site)
      site_name = site["Name"].present? ? site["Name"].strip : "No Site Name"
      existing_site = Hubspot::Site.search_site(site["ID"]) 
      street_address = site["Address"]["Address"] rescue nil
      body_json = {
        "properties": {
          "site": site_name,
          "site_name": site_name,
          " address": site["Address"]["Address"],
          "suburb": site["Address"]["City"],
          "state": site["Address"]["State"],
          "postcode": site["Address"]["PostalCode"],
          "simpro_site_id": site["ID"],
          "country": site["Address"]["Country"],
        }
      }
      if existing_site["results"].blank?
        response = HTTParty.post("#{SITE_PATH}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      else
        site_id = existing_site["results"].first["id"]
        response = HTTParty.patch("#{SITE_PATH}/#{site_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      end

       
      if response.present? && response.success? && site["Customers"].present?
        puts "site created #{site_name}"
        Hubspot::Site.associate_compnay_contact(site["Customers"],response["id"])
      end
    end

    def self.create_update_site(contact_details)
      existing_site = Hubspot::Site.search_site_by_name(contact_details["properties"]["address"]) 
      street_address = contact_details["properties"]["address"] rescue nil
      suburb = contact_details["properties"]["city"] rescue nil
      state = contact_details["properties"]["state"] rescue nil
      postcode = contact_details["properties"]["zip"] rescue nil
      site_name = street_address
      site_address = "#{street_address}, #{suburb}, #{state}, #{postcode}"
      simpro_site = Simpro::Site.get_site(site_name)

      if simpro_site.present?
        site_id = simpro_site.first["ID"]
      else
        Simpro::Site.create_deal_site(site_name,site_address)
        simpro_site = Simpro::Site.get_site(site_name)
        site_id = simpro_site.first["ID"]
      end



      
      body_json = {
        "properties": {
          "site": site_name,
          "site_name": site_name,
          "address": contact_details["properties"]["address"],
          "suburb": contact_details["properties"]["city"],
          "state": contact_details["properties"]["state"],
          "postcode": contact_details["properties"]["zip"],
          "country": "Australia",
          "simpro_site_id": site_id
        }
      }

      if existing_site["results"].present?
        site_id = existing_site["results"].first["id"]
        response = HTTParty.patch("#{SITE_PATH}/#{site_id}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      else
        response = HTTParty.post("#{SITE_PATH}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      end

      if response.present? && response.success?
        return response
      end

    end


    def self.associate_contact(contact_id,site_id)
      body_json =   [
        {
          "associationCategory": "USER_DEFINED",
          "associationTypeId": 59
        }
    ]
    response = HTTParty.put("https://api.hubapi.com/crm/v4/objects/p_sites/#{site_id.to_i}/associations/contacts/#{contact_id.to_i}",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
  end

    def self.search_site(site_id)
       sleep(1)
        body_json =
          {
        "filterGroups":[
          {
            "filters":[
              {
                "propertyName": "simpro_site_id",
                "operator": "EQ",
                "value": "#{site_id}"
              }
            ]
          }
        ]
      }
      response = HTTParty.post("#{SITE_PATH}/search",:body=> body_json.to_json, :headers => {
           "Content-Type" => "application/json","Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
         })

      return response
    end


    def self.search_site_by_name(site_name)
       sleep(1)
        body_json =
          {
        "filterGroups":[
          {
            "filters":[
              {
                "propertyName": "site",
                "operator": "EQ",
                "value": "#{site_name}"
              }
            ]
          }
        ]
      }
      response = HTTParty.post("#{SITE_PATH}/search",:body=> body_json.to_json, :headers => {
           "Content-Type" => "application/json","Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
         })

         HTTParty.get("https://api.hubapi.com/crm/v3/objects/p_sites/124864213477?properties=site",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })

      return response
    end


    def self.associate_compnay_contact(customers,site_id)
      #response = HTTParty.get("https://api.hubapi.com/crm/v4/associations/line_items/quotes/labels",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      customers.each do |f|
        if f["GivenName"].blank?
          hs_company_id = Hubspot::Company.find_company(f["ID"])
          if hs_company_id.present? && hs_company_id["results"].present?
             hs_company_id = hs_company_id["results"].first["id"]
            response = HTTParty.put("https://api.hubapi.com/crm/v3/objects/p_sites/#{site_id}/associations/companies/#{hs_company_id.to_i}/52?paginateAssociations=false",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
          end
        else
          hs_contact_id = Hubspot::Contact.find_user(f["ID"])
          if hs_contact_id.present? && hs_contact_id["results"].present?
            hs_contact_id = hs_contact_id["results"].first["id"]
            response = HTTParty.put("https://api.hubapi.com/crm/v3/objects/p_sites/#{site_id}/associations/contacts/#{hs_contact_id.to_i}/82?paginateAssociations=false",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
          end
        end
      end

    end

  end
end