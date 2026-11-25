# 同期経路（rake の zairyu:daily・画面の「今すぐ実行」・シード）で両サービスを呼ぶ。
# 再試行はしない。例外が出たら job.failed を1行＋Rails.logger.error に残し、結果の ok を false にする。
class DailyCheckRunner
  Result = Struct.new(:notifications_created, :documents_expired, :errors, keyword_init: true) do
    def ok?
      errors.empty?
    end
  end

  def self.call(organization_id = nil)
    new(organization_id).call
  end

  def initialize(organization_id = nil)
    @organization_id = organization_id
  end

  def call
    errors = []
    notifications = run("ExpiryAlertService", errors) { ExpiryAlertService.call(organization_id) }
    documents = run("DocumentExpiryService", errors) { DocumentExpiryService.call(organization_id) }
    Result.new(notifications_created: notifications || 0, documents_expired: documents || 0, errors: errors)
  end

  private

  attr_reader :organization_id

  def run(name, errors)
    yield
  rescue StandardError => e
    JobFailureRecorder.record(name, organization_id, e)
    errors << "#{name}: #{e.class}"
    nil
  end
end
