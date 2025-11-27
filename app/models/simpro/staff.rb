module Simpro
  class Staff
    def self.get_schedule(staff_id)
      # Method : Get
      # Get schedule for a staff

       query = { 
        "columns" => "ID,Staff,TotalHours,Date,Activity,Blocks",
        "search" => "any"
      }


      response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/activitySchedules/?Staff.ID=#{staff_id}",:query=> query, :headers => {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })
      response.parsed_response
    end

    def self.get_current_week_schedule_events(staff_id)
      query = { 
        "columns" => "ID,Staff,Date,Blocks,Type",
        "search" => "all",
        "pageSize" => 100,
        "page" => 1,
        "orderby" => "Date",
      }

      # Request 2025 data specifically
      start_date = Date.today+1.month
      end_date = Date.today+2.month
      response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/schedules/?Date=between(#{start_date},#{end_date})&Staff.ID=#{staff_id}", :query => query, :headers => {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })
      
      schedule_events = []
      
      if response.present? && response.success?
        # Define date range for filtering - only 2025 dates
        start_date = Date.parse("2025-01-01")
        end_date = Date.parse("2025-12-31")
        
        # Process each schedule event to extract required fields
        response.each do |schedule_event|
          # Parse the date from the response and check if it's within our range
          event_date = Date.parse(schedule_event["Date"])
          
          if event_date >= start_date && event_date <= end_date
            if schedule_event["Blocks"].present?
              schedule_event["Blocks"].each do |block|
                event_data = {
                  "staff_id" => staff_id,
                  "event_type" => schedule_event["Activity"]["Name"],
                  "start_time" => block["StartTime"],
                  "end_time" => block["EndTime"],
                  "date" => schedule_event["Date"],
                  "activity_id" => schedule_event["Activity"]["ID"]
                }
                schedule_events << event_data
              end
            end
          end
        end
      end
      
      return schedule_events
    end

    def self.get_sales_consultants
      # Get all sales consultants/staff members
      query = { 
        "columns" => "ID,Name,Position",
        "search" => "any"
      }

      response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/staff/", :query => query, :headers => {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })
      
      if response.present? && response.success?
        # Filter for sales consultants (you may need to adjust the filtering logic based on your data structure)
        sales_consultants = response.select do |staff|
          staff["Position"].present? && 
          (staff["Position"]["Name"].downcase.include?("sales") || 
           staff["Position"]["Name"].downcase.include?("consultant") ||
           staff["Name"].downcase.include?("sales"))
        end
        
        return sales_consultants.map { |consultant| consultant["ID"] }
      end
      
      return []
    end

    def self.get_first_sales_consultant_current_week_schedule
      # Get schedule events for the first sales consultant found
      sales_consultant_ids = get_sales_consultants
      
      if sales_consultant_ids.empty?
        puts "No sales consultants found"
        return []
      end
      
      # Get the first sales consultant
      first_consultant_id = sales_consultant_ids.first
      puts "Getting schedule for first sales consultant (ID: #{first_consultant_id})"
      puts "Date range: 2028-05-01 to 2028-06-01"
      
      schedule_events = get_current_week_schedule_events(first_consultant_id)
      
      puts "Retrieved #{schedule_events.length} schedule events for the specified date range"
      
      # Print summary of events
      if schedule_events.any?
        puts "Schedule events for Staff ID #{first_consultant_id}:"
        schedule_events.each_with_index do |event, index|
          puts "  #{index + 1}. #{event['date']} #{event['start_time']}-#{event['end_time']}: #{event['event_type']}"
        end
      else
        puts "No schedule events found for the specified date range"
      end
      
      return schedule_events
    end
  end
end