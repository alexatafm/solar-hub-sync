#!/usr/bin/env ruby

# Local test script to debug a single job
require 'httparty'
require 'json'

# Load environment variables from .env if it exists
if File.exist?('.env')
  File.readlines('.env').each do |line|
    line = line.strip
    next if line.empty? || line.start_with?('#')
    key, value = line.split('=', 2)
    ENV[key] = value if key && value
  end
end

SIMPRO_API_KEY = ENV['SIMPRO_API_KEY']
SIMPRO_API_URL = ENV['SIMPRO_API_URL']

puts "=" * 80
puts "Testing Single Job from Simpro"
puts "=" * 80

# Fetch job 33784 (the one we tested earlier)
job_id = 33784

puts "\n1. Fetching job #{job_id} from Simpro..."

response = HTTParty.get(
  "#{SIMPRO_API_URL}/jobs/#{job_id}/",
  headers: {
    'Authorization' => "Bearer #{SIMPRO_API_KEY}",
    'Content-Type' => 'application/json'
  },
  query: {
    columns: 'ID,Name,Stage,Status,DateIssued,DateModified,Customer,Site,Salesperson,ProjectManager,CustomFields,Total,Totals'
  }
)

if response.success?
  job = response.parsed_response
  puts "✅ Successfully fetched job"
  puts "\nJob Details:"
  puts "  ID: #{job['ID']}"
  puts "  Name: #{job['Name'].inspect}"
  puts "  Stage: #{job['Stage'].inspect}"
  puts "  Status: #{job['Status']&.dig('Name').inspect}"
  puts "  Customer: #{job['Customer']&.dig('CompanyName').inspect}"
  puts "  Salesperson: #{job['Salesperson']&.dig('Name').inspect}"
  
  puts "\n2. Checking for blank/nil fields:"
  if job['Name'].nil? || job['Name'].to_s.strip.empty?
    puts "  ⚠️  WARNING: Name field is blank/nil!"
  else
    puts "  ✅ Name field looks good: '#{job['Name']}'"
  end
  
  puts "\n3. Raw JSON Response:"
  puts JSON.pretty_generate(job)
else
  puts "❌ Failed to fetch job: #{response.code} - #{response.body}"
end

