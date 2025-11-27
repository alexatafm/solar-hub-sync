class ProcessQuoteJob < ApplicationJob
  queue_as :default

  def perform(quote_id)
    puts "==========Delayed Job Started========== #{Delayed::Job.count}"
    Simpro::Quote.webhook_quote(quote_id)
    puts "==========Delayed Job Ended========== #{Delayed::Job.count}"
  end
end
