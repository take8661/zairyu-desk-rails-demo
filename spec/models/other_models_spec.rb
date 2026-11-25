require "rails_helper"

RSpec.describe "その他のモデル" do
  let(:organization) { create(:organization) }

  describe Organization do
    it "slug は一意で必須" do
      create(:organization, slug: "dup")
      expect(build(:organization, slug: "dup")).not_to be_valid
      expect(build(:organization, slug: nil)).not_to be_valid
    end
  end

  describe User do
    it "メールアドレスは保存前に小文字化・前後空白除去され、一意" do
      user = create(:user, organization: organization, email_address: "  Mixed@Example.COM ")
      expect(user.reload.email_address).to eq("mixed@example.com")
      expect(build(:user, organization: organization, email_address: "MIXED@example.com")).not_to be_valid
    end

    it "role は admin／member だけ。DBのCHECK制約でも拒否される" do
      expect(build(:user, organization: organization, role: "root")).not_to be_valid
      user = create(:user, organization: organization)
      expect { User.where(id: user.id).update_all(role: "root") }.to raise_error(ActiveRecord::StatementInvalid, /CHECK/i)
    end

    it "パスワードは8文字以上" do
      expect(build(:user, organization: organization, password: "short")).not_to be_valid
    end

    it "admin?／member? を返す" do
      expect(build(:user, :admin)).to be_admin
      expect(build(:user)).to be_member
    end

    it "削除するとセッションも消える（dependent: :destroy）" do
      user = create(:user, organization: organization)
      user.sessions.create!(ip_address: "127.0.0.1", user_agent: "rspec")
      expect { user.destroy }.to change(Session, :count).by(-1)
    end
  end

  describe ResidenceCard do
    let(:staff) { create(:staff_member, organization: organization) }

    it "カード番号は下4桁の英数字だけ（小文字は大文字化される）" do
      card = build(:residence_card, staff_member: staff, card_number_last4: "ab12")
      expect(card).to be_valid
      expect(card.card_number_last4).to eq("AB12")
      expect(build(:residence_card, staff_member: staff, card_number_last4: "AB123456")).not_to be_valid
      expect(build(:residence_card, staff_member: staff, card_number_last4: "あい12")).not_to be_valid
    end

    it "交付日より前の期限は無効" do
      expect(build(:residence_card, staff_member: staff, issued_on: Date.current, expires_on: Date.current - 1)).not_to be_valid
    end

    it "在留資格は定義済みの値だけ" do
      expect(build(:residence_card, staff_member: staff, status_of_residence: "宇宙飛行士")).not_to be_valid
    end

    it "スタッフと食い違う organization_id は無効" do
      other = create(:organization)
      card = build(:residence_card, staff_member: staff, organization: other)
      expect(card).not_to be_valid
    end
  end

  describe DocumentType do
    it "名前は組織内で一意" do
      create(:document_type, organization: organization, name: "同名")
      expect(build(:document_type, organization: organization, name: "同名")).not_to be_valid
      expect(build(:document_type, name: "同名")).to be_valid
    end

    it "更新間隔は nil か1以上の整数" do
      expect(build(:document_type, renew_interval_months: nil)).to be_valid
      expect(build(:document_type, renew_interval_months: 12)).to be_valid
      expect(build(:document_type, renew_interval_months: 0)).not_to be_valid
      expect(build(:document_type, renew_interval_months: 1.5)).not_to be_valid
    end

    it "missing の行だけが紐づく種別は、その行ごと削除できる" do
      type = create(:document_type, organization: organization)
      create(:staff_member, organization: organization)
      expect { type.destroy }.to change(StaffDocument, :count).by(-1)
      expect(DocumentType.exists?(type.id)).to be(false)
    end

    it "提出済み以降の書類が紐づく種別は削除できない" do
      type = create(:document_type, organization: organization)
      staff = create(:staff_member, organization: organization)
      staff.staff_documents.find_by!(document_type: type).update!(state: "submitted", submitted_on: Date.current)
      expect(type.destroy).to be(false)
      expect(type.errors[:base].join).to include("削除できません")
    end
  end

  describe Notification do
    it "同じ在留カード・同じ区分は1行だけ（モデル検証とDB一意制約）" do
      staff = create(:staff_member, organization: organization)
      create(:notification, staff_member: staff, kind: "expiry_30")
      expect(build(:notification, staff_member: staff, kind: "expiry_30")).not_to be_valid
      dup = build(:notification, staff_member: staff, kind: "expiry_30")
      expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "kind は定義済みの値だけ。DBのCHECK制約でも拒否される" do
      staff = create(:staff_member, organization: organization)
      note = create(:notification, staff_member: staff, kind: "expiry_60")
      expect(build(:notification, staff_member: staff, kind: "weekly")).not_to be_valid
      expect { Notification.where(id: note.id).update_all(kind: "weekly") }.to raise_error(ActiveRecord::StatementInvalid, /CHECK/i)
    end
  end

  describe Auditable do
    it "作成・更新・削除を audit_logs に残す（Current.user が無ければ user_id は NULL）" do
      type = create(:document_type, organization: organization, name: "監査対象")
      expect(AuditLog.where(target_type: "DocumentType", target_id: type.id, action: "create").count).to eq(1)

      type.update!(name: "監査対象（改）")
      log = AuditLog.where(target_type: "DocumentType", target_id: type.id, action: "update").last
      expect(log.user_id).to be_nil
      expect(log.changes_json["name"]).to eq([ "監査対象", "監査対象（改）" ])
      expect(log.changes_json).not_to have_key("updated_at")

      type.destroy
      expect(AuditLog.where(target_type: "DocumentType", target_id: type.id, action: "destroy").count).to eq(1)
    end

    it "パスワードのハッシュは記録しない" do
      user = create(:user, organization: organization)
      log = AuditLog.where(target_type: "User", target_id: user.id, action: "create").last
      expect(log.changes_json).not_to have_key("password_digest")
    end

    it "変更が無い更新は記録しない" do
      type = create(:document_type, organization: organization)
      expect { type.save! }.not_to change(AuditLog, :count)
    end

    it "ユーザーを削除しても履歴は残り、user_id は NULL になる（on_delete nullify）" do
      editor = create(:user, organization: organization)
      type = create(:document_type, organization: organization)
      Current.session = Session.new(user: editor)
      type.update!(name: "編集者あり")
      Current.reset
      log = AuditLog.where(target_type: "DocumentType", action: "update", user_id: editor.id).last
      expect(log).to be_present
      editor.destroy!
      expect(log.reload.user_id).to be_nil
    end
  end

  describe Current do
    it "Current.organization は Current.user.organization" do
      user = create(:user, organization: organization)
      Current.session = Session.new(user: user)
      expect(Current.organization).to eq(organization)
      Current.reset
      expect(Current.organization).to be_nil
    end
  end
end
