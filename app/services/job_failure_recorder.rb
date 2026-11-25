# ジョブ・同期実行の失敗を audit_logs（action job.failed）と Rails.logger.error に残す。
# 失敗の記録自体が失敗しても、元の処理を止めない（ログにだけ出す）。
class JobFailureRecorder
  def self.record(job_name, organization_id, error)
    Rails.logger.error(
      "job.failed job=#{job_name} organization_id=#{organization_id.inspect} error=#{error.class}: #{error.message}"
    )
    organization_ids = organization_id ? [ organization_id ] : Organization.pluck(:id)
    organization_ids.each do |id|
      AuditLog.create!(
        organization_id: id,
        user_id: nil,
        action: "job.failed",
        target_type: job_name,
        changes_json: { error_class: error.class.name, error_message: error.message }
      )
    end
  rescue StandardError => recording_error
    Rails.logger.error("job.failed の記録に失敗しました: #{recording_error.class}: #{recording_error.message}")
  end
end
