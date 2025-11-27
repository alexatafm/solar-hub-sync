module Simpro
  # Simpro company OBJECT

  class Contact
  	def self.get_contact(contact_id)
  		query = { 
        "columns"     => "ID,GivenName,Title,FamilyName,AltPhone,Department,Email,Position,Fax,WorkPhone,CellPhone,Sites",
        "pageSize"      => 1 
       }
      response = HTTParty.get("#{ENV['SIMPRO_TEST_URL']}/contacts/#{contact_id}",:query=> query, :headers => {
        "Content-Type" => "application/json",
         "Authorization" => "Bearer #{ENV['SIMPRO_TEST_KEY_ID']}"
      })
  	end
  end
end