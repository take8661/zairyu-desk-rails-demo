require "rails_helper"

RSpec.describe StaffMember do
  let(:organization) { create(:organization) }

  describe "検証" do
    it "ファクトリ（在留カード付き）は有効" do
      expect(build(:staff_member, organization: organization)).to be_valid
    end

    it "必須項目が空なら無効" do
      staff = build(:staff_member, organization: organization, full_name: nil, birth_on: nil, nationality: nil, hired_on: nil)
      expect(staff).not_to be_valid
      expect(staff.errors.attribute_names).to include(:full_name, :birth_on, :nationality, :hired_on)
    end

    it "preferred_language は定義済みの言語だけ" do
      expect(build(:staff_member, organization: organization, preferred_language: "xx")).not_to be_valid
    end

    it "status は active／left だけ" do
      expect(build(:staff_member, organization: organization, status: "retired")).not_to be_valid
    end

    it "社員コードは組織内で一意（別の組織なら同じコードでよい）" do
      create(:staff_member, organization: organization, employee_code: "X-1")
      expect(build(:staff_member, organization: organization, employee_code: "X-1")).not_to be_valid
      expect(build(:staff_member, organization: create(:organization), employee_code: "X-1")).to be_valid
    end

    it "作成時に在留カードが0枚なら無効" do
      staff = StaffMember.new(attributes_for(:staff_member).merge(organization: organization))
      expect(staff).not_to be_valid
      expect(staff.errors[:base].join).to include("在留カード")
    end

    it "時給は0以上の整数" do
      expect(build(:staff_member, organization: organization, hourly_wage_yen: -1)).not_to be_valid
    end
  end

  describe "DBの一意制約・CHECK制約" do
    it "status に不正値を直接INSERTするとCHECK制約で拒否される" do
      staff = create(:staff_member, organization: organization)
      expect do
        StaffMember.where(id: staff.id).update_all(status: "unknown")
      end.to raise_error(ActiveRecord::StatementInvalid, /CHECK/i)
    end

    it "(organization_id, employee_code) の重複を直接INSERTすると一意制約で拒否される" do
      create(:staff_member, organization: organization, employee_code: "DUP-1")
      expect do
        row = StaffMember.new(attributes_for(:staff_member).merge(organization: organization, employee_code: "DUP-1"))
        row.save!(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "#current_residence_card" do
    it "expires_on が最大の1件を返す" do
      staff = create(:staff_member, organization: organization, expires_on: Date.current + 100)
      newer = create(:residence_card, staff_member: staff, expires_on: Date.current + 400)
      create(:residence_card, staff_member: staff, expires_on: Date.current + 50)
      expect(staff.reload.current_residence_card).to eq(newer)
    end

    it "同日なら id が大きい方を返す" do
      staff = create(:staff_member, organization: organization, expires_on: Date.current + 100)
      later = create(:residence_card, staff_member: staff, expires_on: Date.current + 100)
      expect(staff.reload.current_residence_card).to eq(later)
    end

    it "includes で読み込み済みでも同じ結果になる（N+1回避用）" do
      staff = create(:staff_member, organization: organization, expires_on: Date.current + 100)
      newer = create(:residence_card, staff_member: staff, expires_on: Date.current + 400)
      loaded = StaffMember.includes(:residence_cards).find(staff.id)
      expect(loaded.current_residence_card).to eq(newer)
    end
  end

  describe ".with_current_card（相関サブクエリ）" do
    it "current の期限・在留資格を列として持ち、期限の昇順に並べられる" do
      a = create(:staff_member, organization: organization, expires_on: Date.current + 300, status_of_residence: "留学")
      b = create(:staff_member, organization: organization, expires_on: Date.current + 10, status_of_residence: "技能実習")
      create(:residence_card, staff_member: b, expires_on: Date.current + 500, status_of_residence: "特定技能1号")
      rows = organization.staff_members.with_current_card.order_by_current_expiry.to_a
      expect(rows.map(&:id)).to eq([ a.id, b.id ])
      expect(rows.last.current_status_of_residence).to eq("特定技能1号")
    end

    it "在留資格で絞り込める" do
      create(:staff_member, organization: organization, status_of_residence: "留学")
      target = create(:staff_member, organization: organization, status_of_residence: "技能実習")
      expect(organization.staff_members.with_current_status_of_residence("技能実習")).to contain_exactly(target)
    end
  end

  describe ".search" do
    it "社員コード・氏名・カナの部分一致。LIKEの特殊文字は無害化される" do
      hit = create(:staff_member, organization: organization, employee_code: "Q-77", full_name: "山田花子", full_name_kana: "ヤマダハナコ")
      create(:staff_member, organization: organization, employee_code: "Q-88", full_name: "佐藤次郎", full_name_kana: "サトウジロウ")
      expect(organization.staff_members.search("Q-77")).to contain_exactly(hit)
      expect(organization.staff_members.search("山田")).to contain_exactly(hit)
      expect(organization.staff_members.search("ヤマダ")).to contain_exactly(hit)
      expect(organization.staff_members.search("%")).to be_empty
    end
  end

  describe "書類の自動作成" do
    it "作成時に、その組織の全書類種別の missing 行を作る" do
      types = create_list(:document_type, 2, organization: organization)
      staff = create(:staff_member, organization: organization)
      expect(staff.staff_documents.pluck(:document_type_id)).to match_array(types.map(&:id))
      expect(staff.staff_documents.pluck(:state).uniq).to eq([ "missing" ])
    end

    it "書類種別を新規作成すると、active なスタッフ全員に missing 行を作る（退職者には作らない）" do
      active_staff = create(:staff_member, organization: organization)
      left_staff = create(:staff_member, :left, organization: organization)
      type = create(:document_type, organization: organization)
      expect(active_staff.staff_documents.where(document_type: type)).to exist
      expect(left_staff.staff_documents.where(document_type: type)).not_to exist
    end
  end

  describe "#missing_required_documents_count" do
    it "必須書類の missing だけを数える" do
      create(:document_type, organization: organization, required: true)
      create(:document_type, organization: organization, required: false)
      staff = create(:staff_member, organization: organization)
      expect(StaffMember.includes(staff_documents: :document_type).find(staff.id).missing_required_documents_count).to eq(1)
    end
  end
end
