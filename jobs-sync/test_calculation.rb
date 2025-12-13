#!/usr/bin/env ruby

# Unit test for percentage calculation
puts "=" * 80
puts "TESTING PERCENTAGE CALCULATION"
puts "=" * 80

# Test data from the HubSpot screenshot
invoiced_value = 1675.89
total_amount_inc_tax = 20826.91

puts "\nTest Case: Job from HubSpot Screenshot"
puts "-" * 80
puts "Invoiced Value: $#{invoiced_value}"
puts "Total Amount Inc Tax: $#{total_amount_inc_tax}"

# OLD calculation (incorrect - multiplies by 100)
old_percentage = (invoiced_value / total_amount_inc_tax * 100).round(2)
puts "\nOLD Formula: (#{invoiced_value} / #{total_amount_inc_tax}) * 100"
puts "OLD Result: #{old_percentage}"
puts "OLD HubSpot Display: #{old_percentage}%"

# NEW calculation (correct - returns decimal)
new_percentage = (invoiced_value / total_amount_inc_tax).round(4)
puts "\nNEW Formula: (#{invoiced_value} / #{total_amount_inc_tax})"
puts "NEW Result: #{new_percentage}"
puts "NEW HubSpot Display: #{(new_percentage * 100).round(2)}%"

puts "\n" + "=" * 80
puts "EXPECTED: ~8.05%"
puts "NEW CALCULATION MATCHES: #{((new_percentage * 100).round(2) >= 8.04 && (new_percentage * 100).round(2) <= 8.06) ? '✅ YES' : '❌ NO'}"
puts "=" * 80

# Test job name fallback
puts "\n\nTESTING JOB NAME FALLBACK"
puts "=" * 80

def present?(value)
  !value.nil? && (value.is_a?(String) ? !value.strip.empty? : (value.respond_to?(:empty?) ? !value.empty? : true))
end

# Test with blank name
job_name = ""
simpro_job_id = 33784

puts "\nTest Case 1: Blank Name"
puts "Original: #{job_name.inspect}"
if !present?(job_name)
  job_name = "Job #{simpro_job_id}"
end
puts "After Fallback: #{job_name.inspect}"
puts present?(job_name) ? "✅ VALID" : "❌ INVALID"

# Test with nil name
job_name = nil
simpro_job_id = 33785

puts "\nTest Case 2: Nil Name"
puts "Original: #{job_name.inspect}"
if !present?(job_name)
  job_name = "Job #{simpro_job_id}"
end
puts "After Fallback: #{job_name.inspect}"
puts present?(job_name) ? "✅ VALID" : "❌ INVALID"

# Test with valid name
job_name = "Deposit sent | Caleb to get customer elec bill"
simpro_job_id = 33786

puts "\nTest Case 3: Valid Name"
puts "Original: #{job_name.inspect}"
if !present?(job_name)
  job_name = "Job #{simpro_job_id}"
end
puts "After Fallback: #{job_name.inspect}"
puts present?(job_name) ? "✅ VALID" : "❌ INVALID"

puts "\n" + "=" * 80
puts "ALL TESTS COMPLETE"
puts "=" * 80

