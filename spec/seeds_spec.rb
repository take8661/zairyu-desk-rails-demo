require "rails_helper"

# db/seeds.rb を実行し、デモデータの件数・指標がすべて一致することを確認する。
RSpec.describe "db/seeds.rb" do
  let(:seeds_path) { Rails.root.join("db/seeds.rb") }

  def run_seeds
    load seeds_path
  end

  before do
    allow($stdout).to receive(:puts) # シード完了メッセージを出さない
    run_seeds
  end

  let(:org_a) { Organization.find_by!(slug: "demo-a") }
  let(:org_b) { Organization.find_by!(slug: "demo-b") }

  describe "組織A「あおぞら製作所（架空）」" do
    it "ユーザー・書類種別・スタッフ・在留カードの件数が設計どおり" do
      expect(org_a.users.pluck(:email_address, :role)).to contain_exactly(
        [ "admin@demo-a.example", "admin" ], [ "member@demo-a.example", "member" ]
      )
      expect(org_a.document_types.count).to eq(5)
      expect(org_a.document_types.where(required: false).pluck(:name)).to eq([ "資格外活動許可書" ])
      expect(org_a.staff_members.count).to eq(12)
      expect(org_a.staff_members.active.count).to eq(11)
      expect(ResidenceCard.where(organization_id: org_a.id).count).to eq(14)
    end

    it "A-012 は退職（left_on は今日の30日前）で、書類は全部 approved" do
      staff = org_a.staff_members.find_by!(employee_code: "A-012")
      expect(staff.status).to eq("left")
      expect(staff.left_on).to eq(Date.current - 30)
      expect(staff.staff_documents.pluck(:state).uniq).to eq([ "approved" ])
    end

    it "全スタッフの必須項目が埋まっている（生年月日・雇用開始日・職種・就業場所・時給・週所定労働時間）" do
      org_a.staff_members.each do |staff|
        expect([ staff.birth_on, staff.hired_on, staff.job_title, staff.workplace, staff.hourly_wage_yen, staff.weekly_hours ]).to all(be_present)
      end
    end

    it "ダッシュボードの指標が期待値と一致する（期限90日以内=6・期限切れ=2・書類未提出=9・書類期限切れ=2）" do
      metrics = DashboardMetrics.new(org_a)
      expect(metrics.expiring_within_90_days_count).to eq(6)
      expect(metrics.expired_count).to eq(2)
      expect(metrics.missing_documents_count).to eq(9)
      expect(metrics.expired_documents_count).to eq(2)
      expect(metrics.upcoming_rows.map { |row| row.staff_member.employee_code })
        .to eq(%w[A-004 A-009 A-003 A-006 A-002 A-010 A-011 A-007])
    end

    it "必須書類44件の内訳が missing 9・expired 2・submitted 8・approved 25" do
      counts = StaffDocument.joins(:document_type, :staff_member)
                            .where(organization_id: org_a.id, document_types: { required: true }, staff_members: { status: "active" })
                            .group(:state).count
      expect(counts).to eq("missing" => 9, "expired" => 2, "submitted" => 8, "approved" => 25)
    end

    it "通知は8件（区分どおり）" do
      kinds = org_a.notifications.joins(:staff_member).pluck("staff_members.employee_code", :kind).to_h
      expect(kinds).to eq(
        "A-003" => "expiry_30", "A-006" => "expiry_30",
        "A-002" => "expiry_60", "A-010" => "expiry_60",
        "A-007" => "expiry_90", "A-011" => "expiry_90",
        "A-004" => "expired", "A-009" => "expired"
      )
    end

    it "資格外活動許可ありは A-006・A-010" do
      codes = ResidenceCard.joins(:staff_member).where(organization_id: org_a.id, permission_for_activity: true)
                           .pluck("staff_members.employee_code")
      expect(codes).to contain_exactly("A-006", "A-010")
    end
  end

  describe "組織B「みなと物流（架空）」" do
    it "admin1名・書類種別3件・スタッフ5名で、氏名はAと重複しない" do
      expect(org_b.users.pluck(:email_address)).to eq([ "admin@demo-b.example" ])
      expect(org_b.document_types.count).to eq(3)
      expect(org_b.staff_members.count).to eq(5)
      expect(org_b.staff_members.pluck(:full_name) & org_a.staff_members.pluck(:full_name)).to be_empty
    end

    it "期限は +20／+70／+200／-5／+400" do
      days = org_b.staff_members.order(:employee_code).map(&:days_left)
      expect(days).to eq([ 20, 70, 200, -5, 400 ])
    end
  end

  describe "冪等性" do
    it "2回実行しても全テーブルの件数が変わらない" do
      tables = [ Organization, User, DocumentType, StaffMember, ResidenceCard, StaffDocument, Notification, AuditLog ]
      before_counts = tables.map(&:count)
      run_seeds
      expect(tables.map(&:count)).to eq(before_counts)
    end
  end

  describe "ログイン用の値" do
    it "環境変数 DEMO_PASSWORD で上書きできる" do
      override = AuthHelpers.test_credential
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("DEMO_PASSWORD", anything).and_return(override)
      User.where(email_address: "admin@demo-a.example").destroy_all
      run_seeds
      expect(User.authenticate_by(email_address: "admin@demo-a.example", password: override)).to be_present
    end
  end
end
