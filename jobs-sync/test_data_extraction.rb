#!/usr/bin/env ruby

# Comprehensive local test for data extraction
require_relative 'sync_jobs'
require 'json'

# Load .env
if File.exist?('.env')
  File.readlines('.env').each do |line|
    line = line.strip
    next if line.empty? || line.start_with?('#')
    key, value = line.split('=', 2)
    ENV[key] = value if key && value
  end
end

puts "=" * 80
puts "COMPREHENSIVE DATA EXTRACTION TEST"
puts "=" * 80

# Test with job 33784 (from the screenshot)
job_id = 33784

# Create sync instance
sync = JobsSync.new(
  simpro_api_key: ENV['SIMPRO_API_KEY'],
  simpro_url: ENV['SIMPRO_API_URL'],
  hubspot_token: ENV['HUBSPOT_ACCESS_TOKEN'],
  pipeline_id: ENV['HUBSPOT_PIPELINE_ID']
)

puts "\n1. Fetching job #{job_id} from Simpro..."
job_details = sync.send(:fetch_simpro_job, job_id)

if job_details
  puts "✅ Successfully fetched job"
  
  puts "\n2. RAW SIMPRO DATA:"
  puts "-" * 80
  puts "Name: #{job_details['Name'].inspect}"
  puts "Stage: #{job_details['Stage'].inspect}"
  puts "Status: #{job_details['Status'].inspect}"
  puts "Total.IncTax: #{job_details.dig('Total', 'IncTax').inspect}"
  puts "Total.ExTax: #{job_details.dig('Total', 'ExTax').inspect}"
  puts "Totals.InvoicedValue: #{job_details.dig('Totals', 'InvoicedValue').inspect}"
  puts "Totals.GrossMargin.Actual: #{job_details.dig('Totals', 'GrossMargin', 'Actual').inspect}"
  
  puts "\n3. EXTRACTING JOB FIELDS..."
  job_data = sync.send(:extract_job_fields, job_details)
  
  puts "\n4. EXTRACTED DATA:"
  puts "-" * 80
  puts "Job Name: #{job_data[:job_name].inspect}"
  puts "Job Status: #{job_data[:job_status].inspect}"
  puts "Pipeline Stage: #{job_data[:pipeline_stage].inspect}"
  puts ""
  puts "Financial Data:"
  puts "  total_amount_inc_tax: #{job_data[:total_amount_inc_tax].inspect}"
  puts "  total_price_inc_tax: #{job_data[:total_price_inc_tax].inspect}"
  puts "  total_price_ex_tax: #{job_data[:total_price_ex_tax].inspect}"
  puts "  invoiced_value: #{job_data[:invoiced_value].inspect}"
  puts "  invoice_percentage: #{job_data[:invoice_percentage].inspect}"
  puts "  actual_gross_margin: #{job_data[:actual_gross_margin].inspect}"
  
  puts "\n5. PERCENTAGE CALCULATION CHECK:"
  puts "-" * 80
  if job_data[:invoiced_value] && job_data[:total_amount_inc_tax]
    calculated = (job_data[:invoiced_value].to_f / job_data[:total_amount_inc_tax].to_f * 100).round(2)
    puts "Formula: (#{job_data[:invoiced_value]} / #{job_data[:total_amount_inc_tax]}) * 100"
    puts "Calculated: #{calculated}%"
    puts "Stored: #{job_data[:invoice_percentage]}%"
    puts calculated == job_data[:invoice_percentage] ? "✅ MATCH" : "❌ MISMATCH!"
  else
    puts "⚠️  Missing data for calculation"
  end
  
  puts "\n6. DATE FIELDS:"
  puts "-" * 80
  puts "date_issued: #{job_data[:date_issued].inspect}"
  puts "date_created: #{job_data[:date_created].inspect}"
  puts "completed_date: #{job_data[:completed_date].inspect}"
  puts "last_modified_date: #{job_data[:last_modified_date].inspect}"
  puts "date_converted_quote: #{job_data[:date_converted_quote].inspect}"
  puts "installation_date: #{job_data[:installation_date].inspect}"
  
  puts "\n7. FORMATTED DATES FOR HUBSPOT:"
  puts "-" * 80
  [:date_issued, :date_created, :completed_date, :last_modified_date, :date_converted_quote, :installation_date].each do |date_field|
    if job_data[date_field]
      formatted = sync.send(:format_date_for_hubspot, job_data[date_field])
      puts "#{date_field}: #{job_data[date_field]} => #{formatted} (#{Time.at(formatted/1000).utc if formatted})"
    end
  end
  
  puts "\n8. HUBSPOT PROPERTIES TO BE SENT:"
  puts "-" * 80
  properties = sync.send(:build_hubspot_properties, job_data)
  
  # Show key properties
  ['jobs', 'stage', 'job_status', 'total_amount_inc_tax_', 'total_price_inc_tax', 
   'total_price_ex_tax', 'invoiced_value', 'invoice_percentage'].each do |prop|
    puts "#{prop}: #{properties[prop].inspect}"
  end
  
  puts "\n9. FULL PROPERTIES JSON:"
  puts "-" * 80
  puts JSON.pretty_generate(properties)
  
else
  puts "❌ Failed to fetch job"
end

