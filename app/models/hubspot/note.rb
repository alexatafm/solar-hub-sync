module Hubspot 
  class Note
    NOTES_PATH = 'https://api.hubapi.com/crm/v3/objects/notes'
    def self.create_user_note(notes,contact_id)
      notes.each do |note|
        note = note['Subject']  rescue "--"

        body_json = {
        "properties": {
           "hs_timestamp": Time.now,
          "hs_note_body": note
        }
       }
        response = HTTParty.post("#{NOTES_PATH}/",:body=> body_json.to_json,:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        if response.present? && response.success?
          response = HTTParty.put("https://api.hubapi.com/crm/v3/objects/contacts/#{contact_id}/associations/notes/#{response["id"].to_i}/#{ENV['CONTACT_NOTE_ASSOCIATION_ID']}?paginateAssociations=false",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })
        end
      end
    end

    def self.create_deal_note(notes,deal_id)
      @notes = []
       notes.each do |note|
        subject = note['Message'].first(65530) rescue "--"
        # deal_email = HTTParty.get("https://api.hubapi.com/crm/v4/objects/emails/#{email["toObjectId"]}?properties=hs_timestamp,hs_email_subject,hs_email_text,hs_email_html,hs_attachment_ids",:headers => { 'Content-Type' => 'application/json',"Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}" })

        create_date = note["Date"].present? ? (note["Date"].to_date.midnight.to_time).to_i*1000 : nil        
        @notes << [{
                    "name": "hs_timestamp",
                    "value": create_date
                  },
                  {
                    "name": "hs_note_body",
                    "value": subject
                  }
                 ]
      end
      batch_create_response = HTTParty.post("https://api.hubapi.com/crm-objects/v1/objects/notes/batch-create",:body=> @notes.to_json, :headers => {"Content-Type" => "application/json","Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"})
      note_ids = batch_create_response.map{ |i| i["properties"]["hs_object_id"]}.map{|i| i["value"]}
      puts "batch create notes"

        from_id = deal_id
        type = "deal_to_note"

        asso_body = {
          inputs: note_ids.map do |to_id|
            { "from" => { "id" => from_id }, "to" => { "id" => to_id }, "type" => type }
          end
        }
      response = HTTParty.post("https://api.hubapi.com/crm/v3/associations/deal/notes/batch/create",:body=> asso_body.to_json, :headers => {"Content-Type" => "application/json","Authorization" => "Bearer #{ENV['HUBSPOT_ACCESS_TOKEN']}"})      # notes.each do |note|
      puts "batch associate notes"
    end
  end
end