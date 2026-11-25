require "rails_helper"

RSpec.describe "書類チェックリスト" do
  let(:organization) { create(:organization) }
  let!(:member) { create(:user, organization: organization) }
  let!(:contract) { create(:document_type, organization: organization, name: "雇用契約書", renew_interval_months: 12) }
  let!(:optional) { create(:document_type, organization: organization, name: "資格外活動許可書", required: false) }
  let!(:staff) { create(:staff_member, organization: organization) }
  let(:doc) { staff.staff_documents.find_by!(document_type: contract) }

  before { sign_in_as(member) }

  def update_doc(document, attrs)
    patch staff_member_staff_document_path(staff, document), params: { staff_document: attrs }
  end

  it "全書類種別の状態を一覧表示する（任意書類には「任意」と出る）" do
    get staff_member_staff_documents_path(staff)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("雇用契約書", "資格外活動許可書", "未提出", "（任意）")
  end

  it "書類種別が無い組織では空状態のメッセージを出す" do
    empty_org = create(:organization)
    empty_staff = create(:staff_member, organization: empty_org)
    delete session_path
    sign_in_as(create(:user, organization: empty_org))
    get staff_member_staff_documents_path(empty_staff)
    expect(response.body).to include("書類種別が登録されていません")
  end

  describe "状態の遷移" do
    it "missing→submitted は提出日が必須（無ければ422でメッセージ）" do
      update_doc(doc, { state: "submitted" })
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("提出日")
      expect(doc.reload.state).to eq("missing")
    end

    it "missing→submitted→approved と進められ、有効期限の既定値が入る" do
      update_doc(doc, { state: "submitted", submitted_on: "2026-04-01" })
      expect(response).to redirect_to(staff_member_staff_documents_path(staff))
      expect(doc.reload).to have_attributes(state: "submitted", expires_on: Date.new(2027, 4, 1))
      update_doc(doc, { state: "approved" })
      expect(doc.reload.state).to eq("approved")
    end

    it "submitted→missing（差し戻し）、approved→submitted（再提出）ができる" do
      update_doc(doc, { state: "submitted", submitted_on: "2026-04-01" })
      update_doc(doc, { state: "missing" })
      expect(doc.reload.state).to eq("missing")
      update_doc(doc, { state: "submitted", submitted_on: "2026-05-01" })
      update_doc(doc, { state: "approved" })
      update_doc(doc, { state: "submitted", submitted_on: "2026-06-01" })
      expect(doc.reload.state).to eq("submitted")
    end

    it "許可されない遷移（missing→approved）は422で状態は変わらない" do
      update_doc(doc, { state: "approved" })
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("へは変更できません")
      expect(doc.reload.state).to eq("missing")
    end

    it "人は期限切れ（expired）にできない（期限切れは毎日の期限チェックだけ）" do
      update_doc(doc, { state: "submitted", submitted_on: "2026-04-01" })
      update_doc(doc, { state: "expired" })
      expect(response).to have_http_status(:unprocessable_entity)
      expect(doc.reload.state).to eq("submitted")
    end

    it "expired→submitted（再提出）はできる" do
      doc.update_columns(state: "expired", submitted_on: Date.current - 400, expires_on: Date.current - 35)
      update_doc(doc, { state: "submitted", submitted_on: Date.current.to_s })
      expect(response).to redirect_to(staff_member_staff_documents_path(staff))
      expect(doc.reload.state).to eq("submitted")
    end

    it "状態を変えずにメモや有効期限だけを更新できる" do
      update_doc(doc, { note: "原本は本社保管", state: "missing" })
      expect(doc.reload.note).to eq("原本は本社保管")
    end

    it "存在しない書類IDは404" do
      patch staff_member_staff_document_path(staff, id: 0), params: { staff_document: { state: "submitted" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  it "更新は audit_logs に、操作したユーザーつきで残る" do
    update_doc(doc, { state: "submitted", submitted_on: "2026-04-01" })
    log = AuditLog.where(target_type: "StaffDocument", target_id: doc.id, action: "update").last
    expect(log.user_id).to eq(member.id)
    expect(log.changes_json["state"]).to eq(%w[missing submitted])
  end
end
