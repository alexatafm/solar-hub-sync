#!/usr/bin/env ruby

# Test script to verify the sync works with a single job
require_relative 'sync_jobs'

# Load .env file if it exists (for local development)
begin
  require 'dotenv'
  Dotenv.load if File.exist?('.env')
rescue LoadError
  # dotenv not available, using environment variables directly
end

class TestJobsSync < JobsSync
  def run_test(max_jobs = 1)
    puts "=" * 80
    puts "Testing Jobs Sync (#{max_jobs} Job#{max_jobs > 1 ? 's' : ''})"
    puts "=" * 80
    puts ""
    
    # Test connection to Simpro
    puts "1. Testing Simpro connection..."
    jobs = fetch_test_job_from_simpro(max_jobs)
    
    if jobs.nil? || jobs.empty?
      puts "❌ Failed to fetch jobs from Simpro"
      return
    end
    
    puts "✅ Successfully connected to Simpro"
    puts "   Found #{jobs.count} jobs to process"
    puts ""
    
    # Process all fetched jobs
    puts "2. Processing #{jobs.count} jobs..."
    puts ""
    
    jobs.each_with_index do |job, index|
      puts "   [#{index + 1}/#{jobs.count}] Processing Job #{job['ID']}..."
      process_job(job)
    end
    
    puts ""
    puts "=" * 80
    puts "Test Summary"
    puts "=" * 80
    puts "Created: #{@stats[:created]}"
    puts "Updated: #{@stats[:updated]}"
    puts "Failed: #{@stats[:failed]}"
    puts ""
    
    if @stats[:failed] > 0
      puts "❌ Test failed - check logs for details"
    elsif @stats[:created] > 0 || @stats[:updated] > 0
      puts "✅ Test successful!"
    else
      puts "⚠️  Test completed but no jobs were created or updated"
    end
  end
  
  private
  
  def fetch_test_job_from_simpro(max_jobs = 1)
    rate_limit_simpro
    
    response = with_retry do
      HTTParty.get(
        "#{@simpro_url}/jobs/",
        query: { page: 0, pageSize: max_jobs },
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@simpro_key}"
        },
        timeout: 60
      )
    end
    
    response.success? ? response.parsed_response : nil
  end
end

# Run the test
if __FILE__ == $0
  # Read MAX_JOBS from environment or default to 1
  max_jobs = (ENV['MAX_JOBS'] || '1').to_i
  max_jobs = 1 if max_jobs < 1 # Ensure at least 1 job
  
  test_sync = TestJobsSync.new
  test_sync.run_test(max_jobs)
end

