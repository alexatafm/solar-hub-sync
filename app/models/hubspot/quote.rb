module Hubspot
  class Quote
    QUOTE_PATH = 'https://api.hubapi.com/crm/v3/objects/quotes'
    
    def self.update_quote(quote, timeline_data, existing_deal)
      if existing_deal["results"].present?
        deal_id = existing_deal["results"].first["id"]
        
        if timeline_data.present?
          deal_notes = HTTParty.get("https://api.hubapi.com/crm/v4/objects/deals/#{deal_id}/associations/notes", headers: { 'Content-Type' => 'application/json', "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
          if deal_notes["results"].present?
            delete_json = {
              "ids": deal_notes["results"].map { |i| i["toObjectId"] }
            }
            HTTParty.post("https://api.hubapi.com/crm-objects/v1/objects/notes/batch-delete", body: delete_json.to_json, headers: { 'Content-Type' => 'application/json', "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
          end
          Hubspot::Note.create_deal_note(timeline_data, deal_id)
        end
        
        # Use optimized display=all approach
        create_line_item(quote["ID"], quote, deal_id, existing_deal)
      end
    end
    
    def self.create_line_item(quote_id, quote, deal_id, existing_deal)
      initial_time = Time.now
      
      # Step 1: Delete existing line items
      line_items = HTTParty.get("https://api.hubapi.com/crm/v4/objects/deals/#{deal_id}/associations/line_items", headers: { 'Content-Type' => 'application/json', "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      if line_items["results"].present?
        delete_json = {
          "ids": line_items["results"].map { |i| i["toObjectId"] }
        }
        HTTParty.post("https://api.hubapi.com/crm-objects/v1/objects/line_items/batch-delete", body: delete_json.to_json, headers: { 'Content-Type' => 'application/json', "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      end
      
      puts "deleted lineitems"
      
      # Step 2: Fetch quote with display=all (OPTIMIZED - single API call)
      quote_full = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}?display=all", headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}" })
      
      # Step 3: Cache labour rates globally
      labour_rates_cache = fetch_labour_rates
      
      # Step 4: Process sections and build line items
      @product = []
      
      if quote_full["Sections"].present?
        quote_full["Sections"].each do |section|
          section_id = section["ID"]
          section_name = section["Name"]
          
          if section["CostCenters"].present?
            section["CostCenters"].each do |cost_center|
              process_cost_center(cost_center, section_id, section_name, labour_rates_cache, quote_full)
            end
          end
        end
      end
      
      # Step 5: Batch create line items
      if @product.any?
        batch_create_response = HTTParty.post("https://api.hubapi.com/crm-objects/v1/objects/line_items/batch-create", body: @product.to_json, headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        
        if batch_create_response.success?
          line_item_ids = batch_create_response.map { |i| i["properties"]["hs_object_id"] }.map { |i| i["value"] }
          
          from_id = deal_id
          type = "deal_to_line_item"
          
          asso_body = {
            inputs: line_item_ids.map do |to_id|
              { "from" => { "id" => from_id }, "to" => { "id" => to_id }, "type" => type }
            end
          }
          deal_acc_response = HTTParty.post("https://api.hubapi.com/crm/v3/associations/deal/line_item/batch/create", body: asso_body.to_json, headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
          puts "batch create line item and deal association"
        else
          puts "Error creating line items: #{batch_create_response.code} - #{batch_create_response.body[0..500]}"
        end
      end
      
      # Step 6: Update Simpro with HubSpot deal ID (always update to ensure correct deal ID after duplicate cleanup)
      Simpro::Quote.update_deal_id(deal_id, quote["ID"])
      
      # Step 7: Update deal properties
      last_time = Time.now
      total_time = last_time - initial_time
      Hubspot::Deal.update_properties(deal_id, quote, total_time)
    end
    
    private
    
    def self.fetch_labour_rates
      labour_rates_response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/setup/labor/laborRates/", headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}" })
      cache = {}
      
      if labour_rates_response.success? && labour_rates_response.any?
        labour_rates_response.each do |rate|
          labour_rate_detail = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/setup/labor/laborRates/#{rate['ID']}", headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}" })
          cache[rate["Name"]] = {
            markup: (labour_rate_detail["Markup"].round(4) rescue 0),
            cost_rate: (labour_rate_detail["CostRate"].round(2) rescue 0)
          }
        end
      end
      
      cache
    end
    
    def self.process_cost_center(cost_center, section_id, section_name, labour_rates_cache, quote)
      cost_center_id = cost_center["ID"]
      cost_center_name = cost_center["CostCenter"]["Name"] rescue cost_center["Name"]
      cost_center_type = cost_center["CostCenter"]["Name"] rescue ""
      cost_center_description = cost_center["Description"] rescue ""
      
      # Fix: Use OptionalDepartment instead of Billable for display=all
      is_optional_department = cost_center["OptionalDepartment"] == true
      primary_optional = is_optional_department ? "Optional" : "Primary"
      
      items = cost_center["Items"]
      return unless items.present?
      
      # Calculate cost-center-specific adjustment ratio
      # simPRO's cost center Total.IncTax already includes discounts but NOT STCs/VEECs
      cc_adjusted_total_inc = cost_center.dig("Total", "IncTax") || 0
      cc_adjusted_total_ex = cost_center.dig("Total", "ExTax") || 0
      
      # Detect if this is a hot water cost center and subtract STCs/VEECs
      # STCs/VEECs only apply to hot water systems, not other cost centers
      is_hot_water = cost_center_name.to_s.match?(/hot.*water|heat.*pump|sanden/i)
      
      if is_hot_water && !is_optional_department
        stcs = quote.dig("Totals", "STCs") || 0
        veecs = quote.dig("Totals", "VEECs") || 0
        cc_adjusted_total_inc -= (stcs + veecs)
        cc_adjusted_total_ex -= ((stcs + veecs) / 1.1).round(2)  # Remove GST component
      end
      
      # Sum all items in this cost center
      cc_items_sum_inc = 0
      cc_items_sum_ex = 0
      
      ["Catalogs", "OneOffs", "Prebuilds", "ServiceFees", "Labors"].each do |item_type|
        if items[item_type] && items[item_type].any?
          items[item_type].each do |item|
            cc_items_sum_inc += item["Total"]["Amount"]["IncTax"] rescue 0
            cc_items_sum_ex += item["Total"]["Amount"]["ExTax"] rescue 0
          end
        end
      end
      
      # Calculate ratios for this cost center
      inc_tax_ratio = cc_items_sum_inc > 0 ? (cc_adjusted_total_inc.to_f / cc_items_sum_inc) : 1
      ex_tax_ratio = cc_items_sum_ex > 0 ? (cc_adjusted_total_ex.to_f / cc_items_sum_ex) : 1
      
      # Process all item types with cost-center-specific ratios
      process_items(items["Catalogs"], "Catalogue", "Catalog", section_id, section_name, cost_center_id, cost_center_name, cost_center_type, cost_center_description, primary_optional, labour_rates_cache, inc_tax_ratio, ex_tax_ratio) if items["Catalogs"].present?
      process_items(items["OneOffs"], "One-Off", "OneOff", section_id, section_name, cost_center_id, cost_center_name, cost_center_type, cost_center_description, primary_optional, labour_rates_cache, inc_tax_ratio, ex_tax_ratio) if items["OneOffs"].present?
      process_items(items["Prebuilds"], "Pre-Builds", "Prebuild", section_id, section_name, cost_center_id, cost_center_name, cost_center_type, cost_center_description, primary_optional, labour_rates_cache, inc_tax_ratio, ex_tax_ratio) if items["Prebuilds"].present?
      process_items(items["ServiceFees"], "Service", "ServiceFee", section_id, section_name, cost_center_id, cost_center_name, cost_center_type, cost_center_description, primary_optional, labour_rates_cache, inc_tax_ratio, ex_tax_ratio) if items["ServiceFees"].present?
      process_items(items["Labors"], "Labour", "LaborType", section_id, section_name, cost_center_id, cost_center_name, cost_center_type, cost_center_description, primary_optional, labour_rates_cache, inc_tax_ratio, ex_tax_ratio) if items["Labors"].present?
    end
    
    def self.process_items(items, type, key, section_id, section_name, cost_center_id, cost_center_name, cost_center_type, cost_center_description, primary_optional, labour_rates_cache, inc_tax_ratio, ex_tax_ratio)
      items.each do |item|
        # NO LONGER SKIP negative prices - we'll handle them as discounts/rebates
        line_item_properties = build_line_item(item, type, key, section_id, section_name, cost_center_id, cost_center_name, cost_center_type, cost_center_description, primary_optional, labour_rates_cache, inc_tax_ratio, ex_tax_ratio)
        @product << line_item_properties if line_item_properties.present?
      end
    end
    
    def self.build_line_item(item, type, key, section_id, section_name, cost_center_id, cost_center_name, cost_center_type, cost_center_description, primary_optional, labour_rates_cache, inc_tax_ratio, ex_tax_ratio)
      # Extract name, SKU, and supplier based on type
      supplier = ""
      
      case key
      when "Catalog"
        product_name = item["Catalog"]["Name"]
        part_no = item["Catalog"]["PartNo"].present? ? item["Catalog"]["PartNo"] : item["ID"].to_s
        supplier = item["Catalog"]["Supplier"]["Name"] rescue ""
        base_price = item["BasePrice"]
        markup = item["Markup"].to_f / 100 rescue 0
      when "OneOff"
        product_name = item["Description"]
        part_no = item["PartNo"].present? ? item["PartNo"] : item["ID"].to_s
        supplier = item["Supplier"]["Name"] rescue ""
        base_price = item["BasePrice"]
        markup = item["Markup"].to_f / 100 rescue 0
      when "Prebuild"
        product_name = item["Prebuild"]["Name"]
        part_no = item["Prebuild"]["PartNo"].present? ? item["Prebuild"]["PartNo"] : item["ID"].to_s
        supplier = item["Prebuild"]["Supplier"]["Name"] rescue ""
        base_price = item["BasePrice"]
        markup = item["Markup"].to_f / 100 rescue 0
      when "ServiceFee"
        product_name = item["ServiceFee"]["Name"]
        part_no = item["ServiceFee"]["PartNo"].present? ? item["ServiceFee"]["PartNo"] : item["ID"].to_s
        base_price = item["BasePrice"]
        markup = item["Markup"].to_f / 100 rescue 0
      when "LaborType"
        product_name = item["LaborType"]["Name"]
        part_no = item["LaborType"]["PartNo"].present? ? item["LaborType"]["PartNo"] : item["ID"].to_s
        
        if labour_rates_cache && labour_rates_cache[product_name]
          markup = labour_rates_cache[product_name][:markup]
          base_price = labour_rates_cache[product_name][:cost_rate]
        else
          markup = 0
          base_price = 0
        end
      end
      
      # Common fields
      amount = item["SellPrice"]["ExTax"].round(2) rescue 0
      quantity = item["Total"]["Qty"].round(2) rescue 0
      discount = item["Discount"].to_f rescue 0
      line_total_ex_tax = item["Total"]["Amount"]["ExTax"].round(2) rescue 0
      line_total_inc_tax = item["Total"]["Amount"]["IncTax"].round(2) rescue 0
      original_price = item["SellPrice"]["ExDiscountExTax"].round(2) rescue amount
      simpro_id = item["ID"].to_s rescue nil
      billable_status = item["BillableStatus"] || (primary_optional == "Primary" ? "Billable" : "Non-Billable")
      
      # Handle negative prices (rebates/discounts)
      is_discount = amount < 0
      discount_amount = is_discount ? amount.abs : 0  # Store absolute value of negative price
      display_price = is_discount ? 0 : amount        # Show $0 for discount items
      
      # Calculate discounted prices using cost-center-specific ratios
      # This applies discounts and STCs/VEECs proportionally within each cost center
      discounted_price_inc_tax = (line_total_inc_tax * inc_tax_ratio).round(2)
      discounted_price_ex_tax = (line_total_ex_tax * ex_tax_ratio).round(2)
      
      # Build properties array for HubSpot with ALL fields (added discounted prices)
      [
        { "name" => "quantity", "value" => quantity },
        { "name" => "name", "value" => product_name },
        { "name" => "price", "value" => display_price },
        { "name" => "discount_amount", "value" => discount_amount },
        { "name" => "costcenter", "value" => cost_center_name },
        { "name" => "primary_optional_cost_centre", "value" => primary_optional },
        { "name" => "section", "value" => section_name },
        { "name" => "costcenter_description", "value" => cost_center_description },
        { "name" => "type", "value" => type },
        { "name" => "costcenter_type", "value" => cost_center_type },
        { "name" => "markup__", "value" => markup },
        { "name" => "cost_price", "value" => base_price },
        { "name" => "hs_sku", "value" => part_no },
        { "name" => "item_discount", "value" => discount },
        { "name" => "line_total__ex_tax_", "value" => line_total_ex_tax },
        { "name" => "line_total__inc_tax_", "value" => line_total_inc_tax },
        { "name" => "original_price_before_discount", "value" => original_price },
        { "name" => "simpro_catalogue_id", "value" => simpro_id },
        { "name" => "billable_status", "value" => billable_status },
        { "name" => "quote_section_id", "value" => section_id.to_s },
        { "name" => "quote_section_name", "value" => section_name },
        { "name" => "quote_cost_centre_id", "value" => cost_center_id.to_s },
        { "name" => "quote_cost_centre_name", "value" => cost_center_name },
        { "name" => "supplier", "value" => supplier },
        { "name" => "discounted_price_inc_tax", "value" => discounted_price_inc_tax },
        { "name" => "discounted_price_ex_tax", "value" => discounted_price_ex_tax }
      ]
    end
    
    def self.find_quote_by_name(quote_name)
      sleep(2)
      body_json = {
        "filterGroups": [
          {
            "filters": [
              {
                "propertyName": "hs_title",
                "operator": "EQ",
                "value": "#{quote_name}"
              }
            ]
          }
        ]
      }
      response = HTTParty.post("#{QUOTE_PATH}/search", body: body_json.to_json, headers: {
        "Content-Type" => "application/json", "Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"
      })
      return response
    end
  end
end

