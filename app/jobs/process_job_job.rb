class ProcessJobJob < ApplicationJob
  queue_as :default

  def perform_now(job_id)
    Simpro::Job.webhook_job(job_id)
  end
end

