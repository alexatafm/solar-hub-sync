class SimproController < ApplicationController
   skip_before_action :verify_authenticity_token

  def quote
		quote_id =  params[:reference]["quoteID"]
		if quote_id.present?
               # ProcessQuoteJob.delay(run_at: 2.seconds.from_now).perform(quote_id)

      ProcessQuoteJob.delay(run_at: 2.seconds.from_now).perform_now(quote_id)
		end
	end

  def job
    job_id = params[:reference]["jobID"]
    if job_id.present?
      ProcessJobJob.delay(run_at: 2.seconds.from_now).perform_now(job_id)
    end
    head :ok
  end
end
