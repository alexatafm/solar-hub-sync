require 'csv'
require 'httparty'
require 'dotenv/load'

# Load the Rails environment
require_relative 'config/environment'

class LineItemCsvSync
  def self.sync_random_deals(count = 2)
    csv_file = 'hubspot-crm-exports-all-deals-2025-11-21.csv'
    
    puts "Reading CSV file: #{csv_file}"
    
    # Read CSV and filter deals with Simpro Quote Id
    deals_with_quotes = []
    CSV.foreach(csv_file, headers: true) do |row|
      next if row['Simpro Quote Id'].nil? || row['Simpro Quote Id'].strip.empty?
      deals_with_quotes << {
        record_id: row['Record ID'],
        deal_name: row['Deal Name'],
        deal_stage: row['Deal Stage'],
        simpro_quote_id: row['Simpro Quote Id'].strip
      }
    end
    
    puts "\nFound #{deals_with_quotes.count} deals with Simpro Quote IDs"
    
    # Select random deals
    random_deals = deals_with_quotes.sample(count)
    
    puts "\n" + "="*80
    puts "Selected #{random_deals.count} random deals for sync:"
    random_deals.each_with_index do |deal, index|
      puts "\n#{index + 1}. Deal Name: #{deal[:deal_name]}"
      puts "   HubSpot Deal ID: #{deal[:record_id]}"
      puts "   Simpro Quote ID: #{deal[:simpro_quote_id]}"
      puts "   Deal Stage: #{deal[:deal_stage]}"
    end
    puts "="*80 + "\n"
    
    # Sync each deal
    random_deals.each_with_index do |deal, index|
      puts "\n" + "-"*80
      puts "Syncing Deal #{index + 1}/#{random_deals.count}"
      puts "-"*80
      
      begin
        sync_single_deal(deal)
      rescue => e
        puts "ERROR syncing deal #{deal[:record_id]}: #{e.message}"
        puts e.backtrace.first(5)
      end
      
      # Small delay between deals to avoid rate limiting
      sleep(2) if index < random_deals.count - 1
    end
    
    puts "\n" + "="*80
    puts "Sync Complete!"
    puts "="*80
    puts "\nPlease check these deals in HubSpot:"
    random_deals.each do |deal|
      puts "- https://app.hubspot.com/contacts/#{ENV['HUBSPOT_PORTAL_ID']}/deal/#{deal[:record_id]}"
    end
  end
  
  def self.sync_single_deal(deal)
    deal_id = deal[:record_id]
    quote_id = deal[:simpro_quote_id]
    
    puts "\nFetching quote #{quote_id} from Simpro..."
    
    # Fetch the quote from Simpro
    query = { 
      "columns" => "ID,Customer,Site,SiteContact,Description,Salesperson,ProjectManager,CustomerContact,Technician,DateIssued,DueDate,DateApproved,OrderNo,Name,Stage,Total,Totals,Status,Tags,Notes,Type,STC,LinkedJobID,ArchiveReason,CustomFields",
      "pageSize" => 1 
    }
    
    quote_response = HTTParty.get(
      "#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}",
      query: query,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      }
    )
    
    unless quote_response.success?
      puts "ERROR: Failed to fetch quote #{quote_id} from Simpro"
      puts "Response Code: #{quote_response.code}"
      puts "Response Body: #{quote_response.body[0..500]}"
      return
    end
    
    quote = quote_response
    puts "✓ Quote fetched successfully: #{quote['Name']}"
    puts "  Quote Total (Ex Tax): $#{quote['Total']['ExTax']}"
    
    # Fetch sections
    puts "\nFetching quote sections..."
    section_response = HTTParty.get(
      "#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/sections/",
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      }
    )
    
    unless section_response.success?
      puts "ERROR: Failed to fetch sections"
      return
    end
    
    puts "✓ Found #{section_response.count} sections"
    
    # Create a mock existing_deal structure
    existing_deal = {
      "results" => [{
        "id" => deal_id
      }]
    }
    
    # Use the existing create_line_item method from Hubspot::Quote
    puts "\nSyncing line items to HubSpot deal #{deal_id}..."
    Hubspot::Quote.create_line_item(quote_id, quote, section_response, deal_id, existing_deal)
    
    puts "✓ Line items synced successfully!"
    puts "\nDeal URL: https://app.hubspot.com/contacts/#{ENV['HUBSPOT_PORTAL_ID']}/deal/#{deal_id}"
  end
end

# Run the sync with 2 random deals
puts "\n" + "="*80
puts "Line Item CSV Sync - Testing Mode"
puts "="*80
puts "\nThis will sync line items from Simpro to HubSpot for 2 random deals."
puts "Press Ctrl+C to cancel or wait 3 seconds to continue..."

sleep(3)

LineItemCsvSync.sync_random_deals(2)

