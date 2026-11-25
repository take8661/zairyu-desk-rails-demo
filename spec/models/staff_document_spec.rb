require "rails_helper"

RSpec.describe StaffDocument do
  let(:organization) { create(:organization) }
  let!(:document_type) { create(:document_type, organization: organization, renew_interval_months: 12) }
  let(:staff) { create(:staff_member, organization: organization) }
  let(:document) { staff.staff_documents.find_by!(document_type: document_type) }

  def transition(doc, to, **attrs)
    doc.update(attrs.merge(state: to))
  end

  describe "状態の遷移" do
    it "missing→submitted は提出日が必須" do
      expect(transition(document, "submitted")).to be(false)
      expect(document.errors[:submitted_on]).to be_present
      expect(transition(document, "submitted", submitted_on: Date.current)).to be(true)
    end

    it "submitted→approved、submitted→missing（差し戻し）、approved→submitted（再提出）が許可される" do
      transition(document, "submitted", submitted_on: Date.current)
      expect(transition(document, "approved")).to be(true)
      expect(transition(document, "submitted", submitted_on: Date.current)).to be(true)
      expect(transition(document, "missing")).to be(true)
    end

    it "expired→submitted（再提出）が許可される" do
      document.update_columns(state: "expired", submitted_on: Date.current - 400, expires_on: Date.current - 35)
      expect(transition(document.reload, "submitted", submitted_on: Date.current)).to be(true)
    end

    {
      %w[missing approved] => "未提出から承認済みへは不可",
      %w[missing expired] => "人は期限切れにできない",
      %w[approved expired] => "approved→expired は期限切れ処理だけ",
      %w[submitted expired] => "submitted→expired は期限切れ処理だけ",
      %w[approved missing] => "承認済みから未提出へは不可",
      %w[expired approved] => "期限切れから承認済みへは不可"
    }.each do |(from, to), reason|
      it "#{from}→#{to}は拒否される（#{reason}）" do
        document.update_columns(state: from, submitted_on: Date.current - 10, expires_on: Date.current + 100)
        expect(transition(document.reload, to)).to be(false)
        expect(document.errors[:state]).to be_present
      end
    end

    it "skip_transition_check を立てたシステム更新は遷移規則を迂回できる" do
      document.update_columns(state: "approved", submitted_on: Date.current - 10, expires_on: Date.current - 1)
      doc = StaffDocument.find(document.id)
      doc.skip_transition_check = true
      expect(doc.update(state: "expired")).to be(true)
    end
  end

  describe "有効期限の既定値" do
    it "空なら提出日に更新間隔の月数を足した日になる" do
      transition(document, "submitted", submitted_on: Date.new(2026, 1, 31))
      expect(document.expires_on).to eq(Date.new(2027, 1, 31))
    end

    it "手入力があればそれを優先する" do
      transition(document, "submitted", submitted_on: Date.new(2026, 1, 1), expires_on: Date.new(2026, 6, 30))
      expect(document.expires_on).to eq(Date.new(2026, 6, 30))
    end

    it "更新間隔が無い書類種別では空のまま" do
      other_type = create(:document_type, organization: organization, renew_interval_months: nil)
      other_doc = staff.staff_documents.find_by!(document_type: other_type)
      transition(other_doc, "submitted", submitted_on: Date.current)
      expect(other_doc.expires_on).to be_nil
    end

    it "期限切れの書類を再提出するとき、古い期限を残さず既定値を計算し直す" do
      document.update_columns(state: "expired", submitted_on: Date.new(2025, 1, 1), expires_on: Date.current - 30)
      transition(document.reload, "submitted", submitted_on: Date.new(2026, 11, 1))
      expect(document.expires_on).to eq(Date.new(2027, 11, 1))
    end
  end

  describe "組織の整合" do
    it "書類種別とスタッフの組織が食い違えば無効" do
      foreign_type = create(:document_type)
      doc = StaffDocument.new(staff_member: staff, document_type: foreign_type, state: "missing")
      expect(doc).not_to be_valid
      expect(doc.errors[:organization_id]).to be_present
    end

    it "organization_id が空なら親（スタッフ）から補う" do
      other_type = create(:document_type, organization: organization)
      doc = staff.staff_documents.find_by!(document_type: other_type)
      expect(doc.organization_id).to eq(organization.id)
    end
  end

  describe "DBのCHECK制約・一意制約" do
    it "state に不正値を直接更新するとCHECK制約で拒否される" do
      expect { StaffDocument.where(id: document.id).update_all(state: "bogus") }
        .to raise_error(ActiveRecord::StatementInvalid, /CHECK/i)
    end

    it "(staff_member_id, document_type_id) の重複を直接INSERTすると一意制約で拒否される" do
      dup = StaffDocument.new(staff_member: staff, document_type: document_type, organization: organization, state: "missing")
      expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
