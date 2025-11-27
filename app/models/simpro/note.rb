module Simpro
  # Simpro Notes OBJECT
  
  class Note
    def self.create_quote_notes(emails,notes,quote_id,deal_id)
      customer_notes = HTTParty.get("https://api.hubapi.com/crm/v4/objects/deals/#{deal_id}/associations/notes?properties",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
      customer_emails = HTTParty.get("https://api.hubapi.com/crm/v4/objects/deals/#{deal_id}/associations/emails?properties",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })

      if customer_notes["results"].present?
        customer_notes["results"].each do |note|
          deal_note = HTTParty.get("https://api.hubapi.com/crm/v4/objects/notes/#{note["toObjectId"]}?properties=hs_timestamp,hs_note_body",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
          if deal_note.present?
            if deal_note["properties"]["hs_createdate"].to_date == Date.today
              subject = Loofah.html5_fragment(deal_note["properties"]["hs_note_body"]).to_text.strip.delete("\n") rescue nil               
              if !notes.any? { |note| note.include?(subject) }
                body_json = {
                  "Note": subject,
                }
                response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/notes/",:body=> body_json.to_json, :headers => {
                  "Content-Type" => "application/json",
                   "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
                }) 
              end
            end
          end
        end
      end
      if customer_emails["results"].present?
        customer_emails["results"].each do |email|
          deal_email = HTTParty.get("https://api.hubapi.com/crm/v4/objects/emails/#{email["toObjectId"]}?properties=hs_timestamp,hs_email_subject,hs_email_text,hs_email_html,hs_attachment_ids",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
          if deal_email.present?
            if deal_email["properties"]["hs_createdate"].to_date == Date.today
              subject = Loofah.html5_fragment(deal_email["properties"]["hs_email_subject"]).to_text.strip.delete("\n") rescue nil               
              body =   deal_email["properties"]["hs_email_html"] rescue nil  
              if deal_email["properties"]["hs_attachment_ids"].present?
                attachment_id = deal_email["properties"]["hs_attachment_ids"].split(';').first
                attachment =  HTTParty.get("https://api.hubspot.com/filemanager/api/v3/files/#{attachment_id}/signed-url",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
              end
              if !emails.any? { |email| email.include?(body) }
                # if attachment.present?
                #    body_json = {
                #   "Subject": subject,
                #   "Note": body,
                #   "Attachments": {
                #      " _href ": attachment["url"],
                #      " FileName ": attachment["name"],
                #     }
                # }
                # else
                   body_json = {
                  "Subject": subject,
                  "Note": body,
                }
                # end
                response = HTTParty.post("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/notes/",:body=> body_json.to_json, :headers => {
                  "Content-Type" => "application/json",
                   "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
                })

              end
            end
          end
        end
      end

    end


    def self.get_quote_notes(quote_id)
      timeline_data =  HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/timelines/", :headers => {
            "Content-Type" => "application/json",
             "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
          })
      note_data =  HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/notes/", :headers => {
          "Content-Type" => "application/json",
           "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
      timeline_note = timeline_data.map{|i|  Loofah.html5_fragment(i["Message"]).to_text.strip.delete("\n")  } rescue []

      quote_note = note_data.map{|i| Loofah.html5_fragment(i["Subject"]).to_text.strip.delete("\n")  } rescue []
      notes = timeline_note + quote_note
       return notes
    end

    def self.get_quote_emails(quote_id)
      timeline_data =  HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/timelines/", :headers => {
            "Content-Type" => "application/json",
             "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
          })
      note_data =  HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/quotes/#{quote_id}/notes/", :headers => {
          "Content-Type" => "application/json",
           "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
        })
      timeline_note = timeline_data.map{|i| i["Message"]  } rescue []

      notes = timeline_note
      return notes
    end

  end


end