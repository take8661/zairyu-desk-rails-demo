require "rails_helper"

RSpec.describe DocumentExpiryService do
  let(:organization) { create(:organization) }
  let(:today) { Date.new(2026, 11, 25) }
  let!(:document_type) { create(:document_type, organization: organization) }
  let(:staff) { create(:staff_member, organization: organization) }
  let(:document) { staff.staff_documents.find_by!(document_type: document_type) }

  def set_document(doc, state:, expires_on:)
    doc.update_columns(state: state, submitted_on: today - 100, expires_on: expires_on)
  end

  it "approved・submitted で期限が今日より前の書類を expired にして件数を返す" do
    approved_doc = document
    set_document(approved_doc, state: "approved", expires_on: today - 1)
    other_type = create(:document_type, organization: organization)
    submitted_doc = staff.staff_documents.find_by!(document_type: other_type)
    set_document(submitted_doc, state: "submitted", expires_on: today - 30)

    expect(described_class.call(organization.id, today: today)).to eq(2)
    expect(approved_doc.reload.state).to eq("expired")
    expect(submitted_doc.reload.state).to eq("expired")
  end

  it "期限が今日（当日）や未来の書類、期限なしの書類、missing の書類は変えない" do
    set_document(document, state: "approved", expires_on: today)
    expect(described_class.call(organization.id, today: today)).to eq(0)
    document.update_columns(expires_on: today + 1)
    expect(described_class.call(organization.id, today: today)).to eq(0)
    document.update_columns(expires_on: nil)
    expect(described_class.call(organization.id, today: today)).to eq(0)
    document.update_columns(state: "missing", expires_on: today - 10)
    expect(described_class.call(organization.id, today: today)).to eq(0)
    expect(document.reload.state).to eq("missing")
  end

  it "退職者の書類は対象外" do
    left_staff = create(:staff_member, :left, organization: organization)
    left_doc = left_staff.staff_documents.find_by!(document_type: document_type)
    set_document(left_doc, state: "approved", expires_on: today - 5)
    expect(described_class.call(organization.id, today: today)).to eq(0)
    expect(left_doc.reload.state).to eq("approved")
  end

  it "audit_logs に update を残す（user_id は NULL）" do
    set_document(document, state: "approved", expires_on: today - 1)
    expect { described_class.call(organization.id, today: today) }.to change {
      AuditLog.where(target_type: "StaffDocument", action: "update", user_id: nil).count
    }.by(1)
    log = AuditLog.where(target_type: "StaffDocument", target_id: document.id, action: "update").last
    expect(log.changes_json["state"]).to eq(%w[approved expired])
  end

  it "organization_id を渡すとその組織だけ、nil なら全組織" do
    other_org = create(:organization)
    other_type = create(:document_type, organization: other_org)
    other_staff = create(:staff_member, organization: other_org)
    other_doc = other_staff.staff_documents.find_by!(document_type: other_type)
    set_document(other_doc, state: "approved", expires_on: today - 1)
    set_document(document, state: "approved", expires_on: today - 1)

    expect(described_class.call(organization.id, today: today)).to eq(1)
    expect(other_doc.reload.state).to eq("approved")
    expect(described_class.call(nil, today: today)).to eq(1)
    expect(other_doc.reload.state).to eq("expired")
  end

  it "期限切れの書類は人の操作で再提出（expired→submitted）できる" do
    set_document(document, state: "approved", expires_on: today - 1)
    described_class.call(organization.id, today: today)
    expect(document.reload.update(state: "submitted", submitted_on: Date.current)).to be(true)
  end
end
