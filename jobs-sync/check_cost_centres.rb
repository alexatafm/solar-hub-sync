require 'httparty'
require 'json'

# Fetch job sections to see if there are cost centres
job_id = 33865
response = HTTParty.get(
  "https://solarhub.simprosuite.com/api/v1.0/companies/4/jobs/#{job_id}/sections/",
  headers: { 'Authorization' => 'Bearer f821239d8ceb2a41b40075d9c8d8e9e1dafaa95c' }
)

if response.success?
  sections = response.parsed_response
  
  puts '=' * 80
  puts "Job #{job_id} - Checking for Cost Centres"
  puts '=' * 80
  puts "Found #{sections.length} sections"
  puts ''
  
  has_cost_centres = false
  
  sections.each do |section|
    section_id = section['ID']
    
    # Fetch cost centres for this section
    cc_response = HTTParty.get(
      "https://solarhub.simprosuite.com/api/v1.0/companies/4/jobs/#{job_id}/sections/#{section_id}/costCenters/",
      headers: { 'Authorization' => 'Bearer f821239d8ceb2a41b40075d9c8d8e9e1dafaa95c' }
    )
    
    if cc_response.success? && cc_response.parsed_response.any?
      has_cost_centres = true
      puts "Section #{section_id}: #{cc_response.parsed_response.length} cost centres found"
      cc_response.parsed_response.each do |cc|
        puts "  - #{cc['CostCenter']['Name']}" if cc['CostCenter']
      end
    end
  end
  
  puts ''
  if has_cost_centres
    puts '✅ This job has cost centres - good for testing!'
  else
    puts '⚠️  This job has NO cost centres'
    puts '   Need to test with a different job'
  end
  puts '=' * 80
end

