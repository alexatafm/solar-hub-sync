module Simpro
  # Simpro company OBJECT
  class Site
  	# def self.create_find_site(site_detail)
    #   site = site_detail["properties"]
  	# 	simpro_site = Simpro::Site.get_site(site["site_name"]["value"])
    #   site_name = site["site_name"]["value"] rescue "--"
    #   site_id = site["hs_object_id"]["value"]
    #   address = site["street_address"].present? && site["street_address"]["value"].present? ? site["street_address"]["value"] : nil
    #   city = site["suburb"].present? && site["suburb"]["value"].present? ? site["suburb"]["value"] : nil
    #   state = site["state"].present? && site["state"]["value"].present? ? site["state"]["value"] : nil
    #   zip = site["post_code"].present? && site["post_code"]["value"].present? ? site["post_code"]["value"] : nil
    #   country = site["country"].present? && site["country"]["value"].present? ? site["country"]["value"] : nil
    #   postal_address = site["postal_address"].present? && site["postal_address"]["value"].present? ? site["postal_address"]["value"] : nil
    #   postal_city = site["postal_suburb"].present? && site["postal_suburb"]["value"].present? ? site["postal_suburb"]["value"] : nil
    #   postal_state = site["postal_state"].present? && site["postal_state"]["value"].present? ? site["postal_state"]["value"] : nil
    #   postal_zip = site["postal_postcode"].present? && site["postal_postcode"]["value"].present? ? site["postal_postcode"]["value"] : nil
    #   body_json = {
    #   "Name": site_name,
    #   "Address": {
    #      "Address": address,
    #      "City": city,
    #      "State": state,
    #      "PostalCode": zip,
    #      "Country": country,
    #     },"BillingAddress": {
    #      "Address": postal_address,
    #      "City": postal_city,
    #      "State": postal_state,
    #      "PostalCode": postal_zip,
    #     }
    #   }
    #   if simpro_site.present?
    #   	site_id = simpro_site.first["ID"]
    #   	response = HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/sites/#{site_id}",:body=> body_json.to_json, :headers => {
    #     "Content-Type" => "application/json",
    #      "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
    #     })
    #   else
    #     response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/sites/",:body=> body_json.to_json, :headers => {
    #     "Content-Type" => "application/json",
    #      "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
    #     }) 
    #     if response.present? && response.success?
    #        Hubspot::Site.update_simpro_id(response["ID"],site_id)
    #     end 
    #   end
    # end

    def self.create_update_site(street_address,suburb,state,postcode,customer_id,quote_details,contact_details)
      site_name = street_address
      site_address = "#{street_address}, #{suburb}, #{state}, #{postcode}"
      simpro_site = Simpro::Site.get_site(site_name)
      zone = Simpro::Site.zone_for_postcode(postcode.to_i)
      if zone[:zone].present?
        zone_no = zone[:zone]
      else
        zone_no = nil
      end
      body_json = {
        "Name": site_name,
        "Customers": customer_id,
        "STCZone": zone_no,
        "Address": {
          "Address": street_address,
          "City": suburb,
          "State": state,
          "PostalCode": postcode,
          "Country": "Australia",
        }
      }
      if simpro_site.present?
        site_id = simpro_site.first["ID"]
        response = HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/sites/#{site_id}",:body=> body_json.to_json, :headers => {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
      else
        response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/sites/",:body=> body_json.to_json, :headers => {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
        site_id = response["ID"]
      end
      if response.present? && response.success?
        query = { 
            "columns"     => "ID,Email,GivenName,FamilyName,WorkPhone,CellPhone,AltPhone",
            "search" => "any"
           }
         site_contacts = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/sites/#{site_id}/contacts/",:query=> query, :headers => {
            "Content-Type" => "application/json",
             "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
          })
          
          # Get phone numbers for matching
          contact_phone = contact_details["properties"] && contact_details["properties"]["phone"]
          contact_mobile = contact_details["properties"] && contact_details["properties"]["mobilephone"]
          
          body_json = {
          "Title": contact_details["properties"]["salutation"],
          "GivenName": contact_details["properties"]["firstname"],
          "FamilyName": contact_details["properties"]["lastname"],
          "Email": contact_details["properties"]["email"],
          "Position": contact_details["properties"]["position"],
          "WorkPhone": contact_details["properties"]["mobilephone"],
          "Fax": contact_details["properties"]["fax"],
          "CellPhone": contact_details["properties"]["mobilephone"],
          "PrimaryContact": true
          }


          if site_contacts.present? && site_contacts.success?
            emails = site_contacts.map{|i| i["Email"]} 
            if emails.include?(contact_details["properties"]["email"])
              site_contact_id =  site_contacts.select{|i| i["Email"] == contact_details["properties"]["email"]}.first["ID"] rescue nil
            # If email doesn't match, try phone number matching
            elsif contact_mobile.present? || contact_phone.present?
              matched_contact = PhoneHelper.find_customer_by_phone(contact_mobile || contact_phone, site_contacts)
              site_contact_id = matched_contact["ID"] if matched_contact.present?
              if site_contact_id.present?
                response = HTTParty.patch("#{ENV['SIMPRO_TEST_URL']}/sites/#{site_id}/contacts/#{site_contact_id}",:body=> body_json.to_json, :headers => {
                "Content-Type" => "application/json",
                  "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
              }) 
              end
            else
              response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/sites/#{site_id}/contacts/",:body=> body_json.to_json, :headers => {
                "Content-Type" => "application/json",
                  "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
              }) 
            end
          else
            response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/sites/#{site_id}/contacts/",:body=> body_json.to_json, :headers => {
              "Content-Type" => "application/json",
                "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
            })    
          end
        Hubspot::Site.update_simpro_id(site_id,site_name)
        if (quote_details["simpro_quote_id"].present? && quote_details["simpro_quote_id"]["value"].blank?) || (quote_details["simpro_quote_id"].blank?)
         Simpro::Quote.create_quote(site_id,customer_id,quote_details,contact_details)
        end
      end
    end


    def self.create_update_site_webhook(site_id)
      query = { 
        "columns"     => "ID,Name,Address,BillingAddress,BillingContact,PrimaryContact,PublicNotes,Zone,Customers,CustomFields",
        "pageSize"      => 1
       }

      response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/sites/#{site_id}",:query=> query, :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })
      if response.present?
          Hubspot::Site.create_site(response)
      else 
        puts "end the loop"
      end
    end

    def self.create_deal_site(site_name,site_address)
       body_json = {
      "Name": site_name,
      "Address": {
         "Address": site_address
        }
      }
      response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/sites/",:body=> body_json.to_json, :headers => {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })
      if response.present? && response.success?
        Hubspot::Site.update_simpro_id(response["ID"],site_name)
      else 
        puts "end the loop"
      end
    end

    def self.get_site(site_name)
      query = { 
           "columns"     => "ID,Name",
           "search" => "any"
         }
      site_name = CGI.escape(site_name)
      response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/sites/?Name=#{site_name}",:query=> query, :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })
    end

    def self.site_webhook(site_id)
      query = { 
           "columns"     => "ID,Name,Address,BillingAddress,BillingContact,PrimaryContact,PublicNotes,Zone,Customers,CustomFields",
           "search" => "any"
         }
      response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/sites/#{site_id}",:query=> query, :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })
      if response.present? && response.success?
        Hubspot::Site.create_site(response)
      else 
        puts "end the loop"
      end
    end

    def self.zone_for_postcode(postcode)
      zones = [
      { range: 0..799, zone: 3 },
      { range: 800..853, zone: 2},
      { range: 854..854, zone: 3 },
      { range: 855..861, zone: 2},
      { range: 862..862, zone: 3 },
      { range: 863..869, zone: 2 },
      { range: 880..899, zone: 2 },
      { range: 870..879, zone: 1 },
      { range: 880..885, zone: 3 },
      { range: 886..1000, zone: 2 },
      { range: 1001..2355, zone: 3 },
      { range: 2356..2357, zone: 2 },
      { range: 2358..2384, zone: 3 },
      { range: 2385..2389, zone: 2 },
      { range: 2390..2395, zone: 3 },
      { range: 2396..2397, zone: 2 },
      { range: 2398..2399, zone: 3 },
      { range: 2400..2400, zone: 2 },
      { range: 2401..2404, zone: 3 },
      { range: 2405..2407, zone: 2 },
      { range: 2408..2544, zone: 3 },
      { range: 2545..2554, zone: 4 },
      { range: 2555..2627, zone: 3 },
      { range: 2628..2628, zone: 4 },
      { range: 2629..2629, zone: 3 },
      { range: 2630..2639, zone: 4 },
      { range: 2640..2816, zone: 3 },
      { range: 2817..2817, zone: 2 },
      { range: 2818..2820, zone: 3 },
      { range: 2821..2829, zone: 2 },
      { range: 2830..2830, zone: 3 },
      { range: 2831..2841, zone: 2 },
      { range: 2842..2872, zone: 3 },
      { range: 2873..2873, zone: 2 },
      { range: 2874..2877, zone: 3 },
      { range: 2878..2889, zone: 2 },
      { range: 2890..2999, zone: 3 },
      { range: 3000..3035, zone: 4 },
      { range: 3036..3038, zone: 3 },
      { range: 3039..3044, zone: 4 },
      { range: 3045..3045, zone: 3 },
      { range: 3046..3046, zone: 4 },
      { range: 3047..3049, zone: 3 },
      { range: 3050..3058, zone: 4 },
      { range: 3059..3059, zone: 3 },
      { range: 3060..3060, zone: 4 },
      { range: 3061..3064, zone: 3 },
      { range: 3065..3074, zone: 4 },
      { range: 3075..3076, zone: 3 },
      { range: 3077..3098, zone: 4 },
      { range: 3099..3099, zone: 3 },
      { range: 3100..3292, zone: 4 },
      { range: 3293..3302, zone: 3 },
      { range: 3303..3308, zone: 4 },
      { range: 3309..3319, zone: 3 },
      { range: 3320..3333, zone: 4 },
      { range: 3334..3337, zone: 3 },
      { range: 3338..3339, zone: 4 },
      { range: 3340..3758, zone: 3 },
      { range: 3759..3760, zone: 4 },
      { range: 3761..3764, zone: 3 },
      { range: 3765..3999, zone: 4 },
      { range: 4000..4416, zone: 3 },
      { range: 4417..4417, zone: 2 },
      { range: 4418..4427, zone: 3 },
      { range: 4428..4473, zone: 2 },
      { range: 4474..4476, zone: 1 },
      { range: 4477..4478, zone: 2 },
      { range: 4479..4485, zone: 1 },
      { range: 4486..4491, zone: 2 },
      { range: 4492..4492, zone: 1 },
      { range: 4493..4493, zone: 2 },
      { range: 4494..4494, zone: 3 },
      { range: 4495..4497, zone: 2 },
      { range: 4498..4719, zone: 3 },
      { range: 4720..4722, zone: 2 },
      { range: 4723..4723, zone: 3 },
      { range: 4724..4734, zone: 2 },
      { range: 4735..4736, zone: 1 },
      { range: 4737..4822, zone: 3 },
      { range: 4823..4823, zone: 2 },
      { range: 4824..4824, zone: 3 },
      { range: 4825..4827, zone: 2 },
      { range: 4828..4828, zone: 3 },
      { range: 4829..4829, zone: 1 },
      { range: 4830..5431, zone: 3 },
      { range: 5432..5450, zone: 2 },
      { range: 5451..5654, zone: 3 },
      { range: 5655..5669, zone: 2 },
      { range: 5670..5679, zone: 3 },
      { range: 5680..5699, zone: 2 },
      { range: 5700..5709, zone: 3 },
      { range: 5710..5722, zone: 2 },
      { range: 5723..5724, zone: 1 },
      { range: 5725..5730, zone: 2 },
      { range: 5731..5731, zone: 1 },
      { range: 5732..5732, zone: 2 },
      { range: 5733..5799, zone: 1 },
      { range: 5800..6043, zone: 3 },
      { range: 6044..6044, zone: 2 },
      { range: 6045..6256, zone: 3 },
      { range: 6257..6270, zone: 4 },
      { range: 6271..6316, zone: 3 },
      { range: 6317..6349, zone: 4 },
      { range: 6350..6353, zone: 3 },
      { range: 6354..6356, zone: 4 },
      { range: 6357..6394, zone: 3 },
      { range: 6395..6400, zone: 4 },
      { range: 6401..6430, zone: 3 },
      { range: 6431..6431, zone: 2 },
      { range: 6432..6433, zone: 3 },
      { range: 6434..6440, zone: 2 },
      { range: 6441..6441, zone: 1 },
      { range: 6442..6444, zone: 3 },
      { range: 6445..6459, zone: 4 },
      { range: 6460..6467, zone: 3 },
      { range: 6468..6469, zone: 2 },
      { range: 6470..6471, zone: 3 },
      { range: 6472..6472, zone: 2 },
      { range: 6473..6506, zone: 3 },
      { range: 6507..6508, zone: 2 },
      { range: 6509..6509, zone: 3 },
      { range: 6510..6536, zone: 2 },
      { range: 6537..6537, zone: 1 },
      { range: 6538..6555, zone: 2 },
      { range: 6556..6573, zone: 3 },
      { range: 6574..6602, zone: 2 },
      { range: 6603..6607, zone: 3 },
      { range: 6608..6641, zone: 2 },
      { range: 6642..6724, zone: 1 },
      { range: 6725..6750, zone: 2 },
      { range: 6751..6764, zone: 1 },
      { range: 6765..6765, zone: 2 },
      { range: 6766..6797, zone: 1 },
      { range: 6798..6799, zone: 2 },
      { range: 6800..6999, zone: 3 },
      { range: 7000..8999, zone: 4 },
      { range: 9000..9999, zone: 3 }
    ].freeze

      entry = zones.find { |e| e[:range].include?(postcode.to_i) }
        entry ? { zone: entry[:zone]} :
          { error: "Postcode #{postcode} not found" }
    end



    # def self.sync_product
    #   for i in 408..700
    #     query = { 
    #       "columns"     => "ID,Name,PartNo,UPC,Manufacturer,CountryOfOrigin,UOM,TradePrice,TradePriceEx,SplitPrice,SellPrice,EstimatedTime,TradeSplitQty,MinPackQty,PurchasingStage,IsFavorite,IsInventory,PurchaseTaxCode,SalesTaxCode,Group,SearchTerm,Notes,Archived",
    #       "pageSize"      => 50,
    #        "page" => i
    #      }

    #     response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/catalogs/?display=all",:query=> query, :headers => {
    #       "Content-Type" => "application/json",
    #        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
    #     })
    #     if response.present?
    #       response.each do |response_data|
    #         Hubspot::Product.create_product(response_data)
    #       end
    #     else
    #        puts "end the loop"
    #     end
    #      puts "-----------------#{i}----------------------------"
    # end
    # end


    # def self.sync_site
    #  for i in 1..111
    #   query = { 
    #     "columns"     => "ID,Name,Address,BillingAddress,BillingContact,PrimaryContact,PublicNotes,Zone,Customers,CustomFields",
    #     "pageSize"      => 50,
    #      "page" => i
    #    }

    #   response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/sites/?display=all",:query=> query, :headers => {
    #       "Content-Type" => "application/json",
    #        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
    #     })


    #     if response.present?
    #       response.each do |response_data|
           
    #         Hubspot::Site.create_site(response_data)
    #       end
    #     else 
    #       puts "end the loop"
    #     end

    #     puts "-----------------#{i}----------------------------"
    #   end
    # end
  end
end