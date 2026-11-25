require "rails_helper"
require "rake"

# 同期経路（サービス直接・rake・今すぐ実行）：再試行せず、失敗は job.failed とログに残す
RSpec.describe "同期の期限チェック" do
  let(:organization) { create(:organization) }

  describe DailyCheckRunner do
    it "両サービスを同期で呼び、件数を返す" do
      create(:staff_member, organization: organization, expires_on: Date.current + 10)
      type = create(:document_type, organization: organization)
      staff = create(:staff_member, organization: organization)
      staff.staff_documents.find_by!(document_type: type)
           .update_columns(state: "approved", submitted_on: Date.current - 400, expires_on: Date.current - 1)

      result = described_class.call(organization.id)
      expect(result).to be_ok
      expect(result.notifications_created).to eq(1) # 残日数10日の1人だけ（もう1人は既定の期限が+200日で対象外）
      expect(result.documents_expired).to eq(1)
    end

    it "片方が失敗しても、もう片方は実行し、失敗は job.failed 1行とログに残す（再試行しない）" do
      create(:staff_member, organization: organization, expires_on: Date.current + 10)
      allow(DocumentExpiryService).to receive(:call).and_raise(StandardError, "書類側の失敗")
      allow(Rails.logger).to receive(:error)

      result = described_class.call(organization.id)

      expect(result).not_to be_ok
      expect(result.errors.join).to include("DocumentExpiryService")
      expect(result.notifications_created).to eq(1)
      expect(DocumentExpiryService).to have_received(:call).once
      expect(AuditLog.where(action: "job.failed", target_type: "DocumentExpiryService").count).to eq(1)
      expect(Rails.logger).to have_received(:error).with(/job\.failed job=DocumentExpiryService/)
    end

    it "失敗の記録そのものが失敗しても例外を外へ出さない" do
      create(:staff_member, organization: organization) # データはスタブより先に作る（作成時の監査ログが影響を受けないように）
      allow(ExpiryAlertService).to receive(:call).and_raise(StandardError, "x")
      allow(AuditLog).to receive(:create!).and_raise(StandardError, "記録も失敗")
      allow(Rails.logger).to receive(:error)
      expect { described_class.call(organization.id) }.not_to raise_error
      expect(Rails.logger).to have_received(:error).with(/job\.failed の記録に失敗しました/)
    end
  end

  describe "rake zairyu:daily" do
    before(:all) do
      Rails.application.load_tasks unless Rake::Task.task_defined?("zairyu:daily")
    end

    let(:task) { Rake::Task["zairyu:daily"] }

    before { task.reenable }

    it "成功すると件数を表示して終了コード0（例外なし）" do
      create(:staff_member, organization: organization, expires_on: Date.current + 10)
      expect { task.invoke }.to output(/新規通知: 1件/).to_stdout
    end

    it "失敗すると終了コード1で終了し、job.failed を残す" do
      create(:staff_member, organization: organization)
      allow(ExpiryAlertService).to receive(:call).and_raise(StandardError, "rake失敗")
      expect do
        expect { task.invoke }.to output(/期限チェックに失敗しました/).to_stderr.and output.to_stdout
      end.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      expect(AuditLog.where(action: "job.failed").count).to be >= 1
    end
  end
end
