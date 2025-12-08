#!/usr/bin/env ruby
# Quick test - does the working v1.1 work?
require 'csv'
require 'httparty'
require 'json'
require 'logger'

ENV['SIMPRO_URL'] ||= 'https://yourcompany.simprosuite.com/api/v1.0/companies/4'
ENV['SIMPRO_API_KEY'] ||= 'your_simpro_api_key_here'
ENV['HUBSPOT_TOKEN'] ||= 'your_hubspot_token_here'
ENV['LIMIT'] ||= '3'

puts "Testing basic HTTParty calls..."
response = HTTParty.get(
  "#{ENV['SIMPRO_URL']}/quotes/55079?display=all",
  headers: {
    "Content-Type" => "application/json",
    "Authorization" => "Bearer #{ENV['SIMPRO_API_KEY']}"
  }
)

if response.success?
  puts "✓ Simpro API works!"
  puts "  Quote ID: #{response['ID']}"
  puts "  Sections: #{response['Sections']&.count || 0}"
else
  puts "✗ Simpro API failed: #{response.code}"
end
