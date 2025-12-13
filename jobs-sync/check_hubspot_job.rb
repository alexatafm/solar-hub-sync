require 'httparty'

job_id = 191642691047
token = ENV['HUBSPOT_ACCESS_TOKEN']

response = HTTParty.get(
  "https://api.hubapi.com/crm/v3/objects/2-185689031/#{job_id}",
  query: { 
    'properties' => 'jobs,job_costcentres,actual_gross_margin'
  },
  headers: { 'Authorization' => "Bearer #{token}" }
)

if response.success?
  props = response.parsed_response['properties']
  gm = (props['actual_gross_margin'].to_f * 100).round(2)
  
  puts '=' * 80
  puts '🎯 HUBSPOT JOB - COST CENTRES CHECK'
  puts '=' * 80
  puts "Job Name: #{props['jobs']}"
  puts "Gross Margin: #{gm}%"
  puts ''
  puts '📋 Cost Centres:'
  
  if props['job_costcentres'] && !props['job_costcentres'].empty?
    cost_centres = props['job_costcentres'].split(';')
    cost_centres.each do |cc|
      puts "  ✓ #{cc}"
    end
    puts ''
    puts "✅ #{cost_centres.length} cost centre(s) synced successfully!"
  else
    puts '  (None)'
    puts ''
    puts '⚠️  No cost centres synced - job may not have any'
  end
  puts '=' * 80
end

