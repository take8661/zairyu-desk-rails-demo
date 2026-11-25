require "rails_helper"

RSpec.describe "組織設定（admin のみ）" do
  let(:organization) { create(:organization, name: "設定テスト製作所") }
  let!(:admin) { create(:user, :admin, organization: organization, email_address: "admin@settings.example") }

  before { sign_in_as(admin) }

  describe "組織名" do
    it "表示と変更ができる" do
      get settings_organization_path
      expect(response.body).to include("設定テスト製作所", "今すぐ実行")
      patch settings_organization_path, params: { organization: { name: "新しい組織名" } }
      expect(response).to redirect_to(settings_organization_path)
      expect(organization.reload.name).to eq("新しい組織名")
    end

    it "空の組織名は422" do
      patch settings_organization_path, params: { organization: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(organization.reload.name).to eq("設定テスト製作所")
    end

    it "編集フォームが表示される" do
      get edit_settings_organization_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "ユーザー管理" do
    let!(:member) { create(:user, organization: organization, email_address: "member@settings.example") }

    it "一覧に自組織のユーザーが出て、自分には「あなた」が付き削除ボタンが無い" do
      get settings_users_path
      expect(response.body).to include("admin@settings.example", "member@settings.example", "（あなた）")
    end

    it "追加フォームが表示され、ユーザーを追加できる（初期パスワード8文字以上）" do
      get new_settings_user_path
      expect(response).to have_http_status(:ok)
      expect do
        post settings_users_path, params: { user: { email_address: "NewUser@Settings.Example", role: "member", password: "initial-pass-1" } }
      end.to change { organization.users.count }.by(1)
      expect(response).to redirect_to(settings_users_path)
      expect(organization.users.find_by!(email_address: "newuser@settings.example").role).to eq("member")
    end

    it "メールアドレスの重複・短い初期パスワードは422" do
      post settings_users_path, params: { user: { email_address: "member@settings.example", role: "member", password: "initial-pass-1" } }
      expect(response).to have_http_status(:unprocessable_entity)
      post settings_users_path, params: { user: { email_address: "short@settings.example", role: "member", password: "short" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "他のユーザーの role を変更でき、パスワード欄が空ならパスワードは変わらない" do
      before_digest = member.password_digest
      patch settings_user_path(member), params: { user: { role: "admin", password: "" } }
      expect(response).to redirect_to(settings_users_path)
      expect(member.reload.role).to eq("admin")
      expect(member.password_digest).to eq(before_digest)
    end

    it "パスワードを入力すれば変更される" do
      before_digest = member.password_digest
      patch settings_user_path(member), params: { user: { password: "changed-pass-9" } }
      expect(member.reload.password_digest).not_to eq(before_digest)
    end

    it "自分自身の role は変更できない（422で role は変わらない）" do
      patch settings_user_path(admin), params: { user: { role: "member" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("自分自身では変更できません")
      expect(admin.reload.role).to eq("admin")
    end

    it "自分自身の削除はできない（403でユーザーが残る）" do
      expect { delete settings_user_path(admin) }.not_to change(User, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "編集履歴（audit_logs）のある member を削除しても、一覧へ戻り、履歴は残って user_id が NULL になる" do
      delete session_path
      sign_in_as(member)
      staff = create(:staff_member, organization: organization)
      patch staff_member_path(staff), params: { staff_member: { full_name: "member が編集" } }
      log = AuditLog.where(target_type: "StaffMember", target_id: staff.id, action: "update", user_id: member.id).last
      expect(log).to be_present
      delete session_path

      sign_in_as(admin)
      expect { delete settings_user_path(member) }.to change(User, :count).by(-1)
      expect(response).to redirect_to(settings_users_path)
      expect(response).to have_http_status(:see_other)
      expect(AuditLog.find(log.id).user_id).to be_nil
      expect(Session.where(user_id: member.id)).to be_empty
    end
  end

  describe "書類種別" do
    let!(:staff) { create(:staff_member, organization: organization) }
    let!(:existing) { create(:document_type, organization: organization, name: "既存の種別") }

    it "一覧・追加フォーム・編集フォームが表示される" do
      get settings_document_types_path
      expect(response.body).to include("既存の種別")
      get new_settings_document_type_path
      expect(response).to have_http_status(:ok)
      get edit_settings_document_type_path(existing)
      expect(response).to have_http_status(:ok)
    end

    it "追加すると、在籍中の全スタッフに missing の行が作られる" do
      expect do
        post settings_document_types_path, params: { document_type: { name: "新しい種別", required: "1", renew_interval_months: "6" } }
      end.to change { staff.staff_documents.count }.by(1)
      created = organization.document_types.find_by!(name: "新しい種別")
      expect(created.renew_interval_months).to eq(6)
      expect(staff.staff_documents.find_by!(document_type: created).state).to eq("missing")
    end

    it "名称の重複・更新間隔0は422" do
      post settings_document_types_path, params: { document_type: { name: "既存の種別" } }
      expect(response).to have_http_status(:unprocessable_entity)
      post settings_document_types_path, params: { document_type: { name: "間隔ゼロ", renew_interval_months: "0" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "名称・必須・更新間隔を更新できる" do
      patch settings_document_type_path(existing), params: { document_type: { name: "改名", required: "0", renew_interval_months: "" } }
      expect(response).to redirect_to(settings_document_types_path)
      expect(existing.reload).to have_attributes(name: "改名", required: false, renew_interval_months: nil)
    end

    it "missing の行だけが紐づく種別は削除でき、その行も消える" do
      expect { delete settings_document_type_path(existing) }.to change(DocumentType, :count).by(-1)
      expect(response).to redirect_to(settings_document_types_path)
      expect(StaffDocument.where(document_type_id: existing.id)).to be_empty
    end

    it "missing 以外の書類が紐づく種別の削除は422＋メッセージで、種別は残る" do
      staff.staff_documents.find_by!(document_type: existing).update!(state: "submitted", submitted_on: Date.current)
      expect { delete settings_document_type_path(existing) }.not_to change(DocumentType, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("削除できません")
    end
  end

  describe "ジョブの「今すぐ実行」" do
    let!(:near) { create(:staff_member, organization: organization, expires_on: Date.current + 10) }
    let!(:other_org_staff) { create(:staff_member, expires_on: Date.current + 10) }

    it "同期でサービスを呼び、押した組織だけを対象に、新規通知件数を表示する" do
      post settings_run_jobs_path
      expect(response).to redirect_to(settings_organization_path)
      follow_redirect!
      expect(response.body).to include("新規通知 1件", "期限切れに更新した書類 0件")
      expect(near.notifications.count).to eq(1)
      expect(other_org_staff.notifications.count).to eq(0)
    end

    it "2回押しても通知は増えない（冪等）" do
      post settings_run_jobs_path
      expect { post settings_run_jobs_path }.not_to change(Notification, :count)
      follow_redirect!
      expect(response.body).to include("新規通知 0件")
    end

    it "期限切れの書類を expired に更新した件数を表示する" do
      type = create(:document_type, organization: organization)
      near.reload.staff_documents.find_by!(document_type: type).update_columns(state: "approved", submitted_on: Date.current - 400, expires_on: Date.current - 1)
      post settings_run_jobs_path
      follow_redirect!
      expect(response.body).to include("期限切れに更新した書類 1件")
    end

    it "perform_later（ジョブ経由）は使わない" do
      ActiveJob::Base.queue_adapter = :test
      expect { post settings_run_jobs_path }.not_to have_enqueued_job
    end

    it "失敗したら「実行に失敗しました（詳細はログ）」を表示し、job.failed を残す" do
      allow(ExpiryAlertService).to receive(:call).and_raise(StandardError, "実行時エラー")
      allow(Rails.logger).to receive(:error)
      post settings_run_jobs_path
      follow_redirect!
      expect(response.body).to include("実行に失敗しました（詳細はログ）")
      expect(AuditLog.where(organization_id: organization.id, action: "job.failed").count).to eq(1)
      expect(Rails.logger).to have_received(:error).with(/job\.failed/)
    end
  end
end
