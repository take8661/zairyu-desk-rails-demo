# ExpiryAlertService を呼ぶだけの薄い包み（perform_later 経路。将来 Solid Queue で定期実行する想定の入口）。
# 3回失敗して再試行を使い切ると、ブロックが呼ばれて job.failed を記録する。
class ExpiryAlertJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.seconds, attempts: 3 do |job, error|
    JobFailureRecorder.record(job.class.name, job.arguments.first, error)
  end

  def perform(organization_id = nil)
    ExpiryAlertService.call(organization_id)
  end
end
