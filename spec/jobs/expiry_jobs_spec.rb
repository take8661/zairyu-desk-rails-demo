require "rails_helper"

RSpec.describe "期限ジョブ" do
  let(:organization) { create(:organization) }

  before do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  describe ExpiryAlertJob do
    it "ExpiryAlertService を呼ぶだけの薄い包み（perform_now で通知が作られる）" do
      staff = create(:staff_member, organization: organization, expires_on: Date.current + 10)
      expect { described_class.perform_now(organization.id) }.to change { staff.notifications.count }.by(1)
    end

    it "引数なしなら全組織が対象" do
      other = create(:staff_member, expires_on: Date.current + 10)
      create(:staff_member, organization: organization, expires_on: Date.current + 10)
      described_class.perform_now
      expect(other.notifications.count).to eq(1)
    end

    it "2回実行しても通知は増えない（冪等）" do
      create(:staff_member, organization: organization, expires_on: Date.current + 10)
      described_class.perform_now(organization.id)
      expect { described_class.perform_now(organization.id) }.not_to change(Notification, :count)
    end

    it "perform_later でキューに積まれる" do
      expect { described_class.perform_later(organization.id) }.to have_enqueued_job(described_class).with(organization.id)
    end

    it "3回失敗して再試行を使い切ると、audit_logs に job.failed が1件できて Rails.logger.error にも出る" do
      allow(ExpiryAlertService).to receive(:call).and_raise(StandardError, "boom")
      allow(Rails.logger).to receive(:error)

      # 【未確認事項の確認】待ち時間（wait: 5.seconds）付きの再試行が perform_enqueued_jobs で実行されること
      perform_enqueued_jobs { described_class.perform_later(organization.id) }

      expect(ExpiryAlertService).to have_received(:call).exactly(3).times
      logs = AuditLog.where(action: "job.failed")
      expect(logs.count).to eq(1)
      expect(logs.first.target_type).to eq("ExpiryAlertJob")
      expect(logs.first.organization_id).to eq(organization.id)
      expect(logs.first.user_id).to be_nil
      expect(logs.first.changes_json).to include("error_class" => "StandardError", "error_message" => "boom")
      expect(Rails.logger).to have_received(:error).with(/job\.failed job=ExpiryAlertJob .*boom/)
    end

    it "1〜2回失敗しても、その後成功すれば job.failed は残らない" do
      create(:staff_member, organization: organization, expires_on: Date.current + 10)
      calls = 0
      allow(ExpiryAlertService).to receive(:call).and_wrap_original do |original, *args|
        calls += 1
        raise StandardError, "一時的な失敗" if calls < 3

        original.call(*args)
      end
      perform_enqueued_jobs { described_class.perform_later(organization.id) }
      expect(AuditLog.where(action: "job.failed")).to be_empty
      expect(Notification.count).to eq(1)
    end
  end

  describe DocumentExpiryJob do
    it "DocumentExpiryService を呼ぶだけの薄い包み（期限切れの書類が expired になる）" do
      type = create(:document_type, organization: organization)
      staff = create(:staff_member, organization: organization)
      doc = staff.staff_documents.find_by!(document_type: type)
      doc.update_columns(state: "approved", submitted_on: Date.current - 400, expires_on: Date.current - 1)
      described_class.perform_now(organization.id)
      expect(doc.reload.state).to eq("expired")
    end

    it "3回失敗で audit_logs に job.failed が1件できる" do
      allow(DocumentExpiryService).to receive(:call).and_raise(RuntimeError, "db down")
      perform_enqueued_jobs { described_class.perform_later(organization.id) }
      log = AuditLog.where(action: "job.failed").sole
      expect(log.target_type).to eq("DocumentExpiryJob")
      expect(log.changes_json["error_class"]).to eq("RuntimeError")
    end
  end
end
