module PhoneHelper
  # Normalize phone numbers to digits only for comparison
  # Handles various formats:
  # - +61 XXX XXX XXX (HubSpot format)
  # - 04XXXXXXXX
  # - 04XX XXX XXX
  # - 61 4XX XXX XXX
  # - +61 4XX XXX XXX
  # - +61XXXXXXXXX
  
  def self.normalize(phone_number)
    return nil if phone_number.nil? || phone_number.to_s.strip.empty?
    
    # Remove all non-digit characters
    normalized = phone_number.to_s.gsub(/[^0-9]/, '')
    
    return nil if normalized.empty?
    
    # Remove leading country code variations
    # If starts with 61 and has 11 digits total, remove the 61
    if normalized.start_with?('61') && normalized.length == 11
      normalized = normalized[2..-1]
    end
    
    # If starts with 61 and has 10 digits after, remove the 61
    if normalized.start_with?('61') && normalized.length >= 10
      normalized = '0' + normalized[2..-1]
    end
    
    # Ensure it starts with 0 for Australian mobile numbers
    unless normalized.start_with?('0')
      normalized = '0' + normalized if normalized.length == 9
    end
    
    normalized
  end
  
  # Compare two phone numbers, returns true if they match
  def self.match?(phone1, phone2)
    return false if phone1.nil? || phone1.to_s.strip.empty? || phone2.nil? || phone2.to_s.strip.empty?
    
    normalized1 = normalize(phone1)
    normalized2 = normalize(phone2)
    
    return false if normalized1.nil? || normalized1.empty? || normalized2.nil? || normalized2.empty?
    
    normalized1 == normalized2
  end
  
  # Find a customer by matching phone numbers
  # Searches through Phone, AltPhone, and CellPhone fields
  def self.find_customer_by_phone(phone_number, existing_customers)
    return nil if phone_number.nil? || phone_number.to_s.strip.empty? || existing_customers.nil? || existing_customers.empty?
    
    normalized_search = normalize(phone_number)
    return nil if normalized_search.nil? || normalized_search.empty?
    
    existing_customers.find do |customer|
      match?(customer["Phone"], phone_number) ||
      match?(customer["AltPhone"], phone_number) ||
      match?(customer["CellPhone"], phone_number)
    end
  end
end

