# DocumentExpiryService を呼ぶだけの薄い包み（perform_later 経路）。
class DocumentExpiryJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.seconds, attempts: 3 do |job, error|
    JobFailureRecorder.record(job.class.name, job.arguments.first, error)
  end

  def perform(organization_id = nil)
    DocumentExpiryService.call(organization_id)
  end
end
