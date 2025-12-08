#!/usr/bin/env ruby

# Test the Railway sync function locally before deploying

require_relative 'railway_sync_function'

puts "\n" + "="*80
puts "TESTING RAILWAY SYNC FUNCTION LOCALLY"
puts "="*80
puts "\nThis will sync 5 deals as a test...\n"

# Set test parameters
ENV['LIMIT'] = '5'
ENV['START_FROM'] = '0'

# Run the sync
syncer = RailwayLineItemSync.new
syncer.run(
  csv_file: 'hubspot-crm-exports-all-deals-2025-11-21.csv',
  limit: 5,
  start_from: 0
)

puts "\n✓ Test completed! Check the log file for details."
puts "If this looks good, deploy to Railway with: railway up"

