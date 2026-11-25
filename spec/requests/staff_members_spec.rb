require "rails_helper"

RSpec.describe "スタッフ" do
  let(:organization) { create(:organization) }
  let!(:admin) { create(:user, :admin, organization: organization) }
  let!(:doc_type) { create(:document_type, organization: organization, name: "パスポート写し") }

  before { sign_in_as(admin) }

  def valid_params(overrides = {})
    {
      staff_member: {
        employee_code: "N-001", full_name: "新規 太郎", full_name_kana: "シンキ タロウ", birth_on: "1995-01-01",
        nationality: "ベトナム", preferred_language: "vi", hired_on: "2025-04-01", job_title: "検品", workplace: "第一工場",
        hourly_wage_yen: "1200", weekly_hours: "40",
        residence_cards_attributes: {
          "0" => { status_of_residence: "特定技能1号", card_number_last4: "ab12", issued_on: "2025-01-01", expires_on: "2028-01-01", permission_for_activity: "0" }
        }
      }.deep_merge(overrides)
    }
  end

  describe "一覧" do
    let!(:expired) { create(:staff_member, organization: organization, employee_code: "E-1", full_name: "期限切れ 花子", expires_on: Date.current - 4) }
    let!(:soon) { create(:staff_member, organization: organization, employee_code: "S-1", full_name: "もうすぐ 次郎", expires_on: Date.current + 20, status_of_residence: "留学") }
    let!(:far) { create(:staff_member, organization: organization, employee_code: "F-1", full_name: "まだ先 三郎", expires_on: Date.current + 500) }
    let!(:left_staff) { create(:staff_member, :left, organization: organization, employee_code: "L-1", full_name: "退職 四郎") }

    it "既定は在籍中のみで、在留期間満了日の昇順（期限切れが先頭）" do
      get staff_members_path
      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body).not_to include("退職 四郎")
      expect(body.index("E-1")).to be < body.index("S-1")
      expect(body.index("S-1")).to be < body.index("F-1")
    end

    it "表示列：社員コード・氏名・国籍・在留資格・満了日・残日数・書類の未提出数、区分バッジ（文字ラベル付き）" do
      get staff_members_path
      expect(response.body).to include("社員コード", "氏名", "国籍", "在留資格", "在留期間満了日", "残日数", "書類の未提出")
      expect(response.body).to include("期限切れ", "30日以内")
      expect(response.body).to include("4日超過", "あと20日")
    end

    it "q で社員コード・氏名の部分一致検索ができる" do
      get staff_members_path, params: { q: "もうすぐ" }
      expect(response.body).to include("S-1")
      expect(response.body).not_to include("F-1")
      get staff_members_path, params: { q: "F-1" }
      expect(response.body).to include("まだ先 三郎")
      expect(response.body).not_to include("S-1")
    end

    it "検索語のLIKE特殊文字（%）は無害化されて全件マッチにならない" do
      get staff_members_path, params: { q: "%" }
      expect(response.body).to include("条件に合うスタッフがいません")
    end

    it "在留資格で絞り込める（current の在留資格）" do
      get staff_members_path, params: { status_of_residence: "留学" }
      expect(response.body).to include("S-1")
      expect(response.body).not_to include("E-1")
    end

    it "status=left で退職者、status=all で全員" do
      get staff_members_path, params: { status: "left" }
      expect(response.body).to include("退職 四郎")
      expect(response.body).not_to include("E-1")
      get staff_members_path, params: { status: "all" }
      expect(response.body).to include("退職 四郎", "E-1", "F-1")
    end

    it "該当なしなら空状態のメッセージを出す" do
      get staff_members_path, params: { q: "存在しない名前" }
      expect(response.body).to include("条件に合うスタッフがいません")
    end

    it "書類の未提出数（必須の missing）を表示する" do
      get staff_members_path
      expect(response.body).to match(%r{<td class="num">1</td>})
    end
  end

  describe "詳細" do
    let!(:staff) { create(:staff_member, organization: organization, expires_on: Date.current + 100) }

    it "基本情報・在留カード履歴（新しい順）・書類チェックリストへのリンクを表示する" do
      create(:residence_card, staff_member: staff, expires_on: Date.current + 500, status_of_residence: "技術・人文知識・国際業務")
      get staff_member_path(staff)
      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body).to include(staff.full_name, "在留カードの履歴", staff_member_staff_documents_path(staff))
      expect(body.index("技術・人文知識・国際業務")).to be < body.index("特定技能1号")
    end

    it "在留カード番号は下4桁だけ表示し、全桁は出ない" do
      get staff_member_path(staff)
      expect(response.body).to include("AB12")
      expect(response.body).not_to match(/[A-Z]{2}\d{8}[A-Z]{2}/)
    end

    it "存在しないIDは日本語の404画面" do
      get staff_member_path(id: 0)
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("404", "ページが見つかりません")
    end
  end

  describe "登録" do
    it "登録フォームが表示される（最初の在留カードの入力欄つき）" do
      get new_staff_member_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("最初の在留カード", "カード番号の下4桁")
    end

    it "スタッフと在留カードを1つのフォームで作成し、書類（missing）も自動で作られる" do
      expect { post staff_members_path, params: valid_params }
        .to change { organization.staff_members.count }.by(1)
        .and change(ResidenceCard, :count).by(1)
        .and change(StaffDocument, :count).by(1)
      staff = organization.staff_members.find_by!(employee_code: "N-001")
      expect(response).to redirect_to(staff_member_path(staff))
      expect(staff.current_residence_card.card_number_last4).to eq("AB12")
      expect(staff.staff_documents.sole.state).to eq("missing")
    end

    it "必須項目が空なら422でフォームを再表示し、エラーを日本語で出す" do
      post staff_members_path, params: valid_params(full_name: "")
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("入力内容を確認してください")
      expect(organization.staff_members.count).to eq(0)
    end

    it "在留カードが無ければ422（作成時に最低1枚が必須）" do
      post staff_members_path, params: { staff_member: valid_params[:staff_member].except(:residence_cards_attributes) }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("在留カードを1枚以上入力してください")
    end

    it "社員コードが重複すると422" do
      create(:staff_member, organization: organization, employee_code: "N-001")
      post staff_members_path, params: valid_params
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "在留カード番号が英数字4文字でなければ422" do
      overrides = { residence_cards_attributes: { "0" => { card_number_last4: "AB123456" } } }
      post staff_members_path, params: valid_params(overrides)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "編集・更新" do
    let!(:staff) { create(:staff_member, organization: organization, full_name: "変更前") }

    it "編集フォームが表示される（在留カード入力欄は出ない）" do
      get edit_staff_member_path(staff)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("最初の在留カード")
    end

    it "基本情報を更新できる。退職は status を left にして行う" do
      patch staff_member_path(staff), params: { staff_member: { full_name: "変更後", status: "left", left_on: "2026-11-01" } }
      expect(response).to redirect_to(staff_member_path(staff))
      expect(staff.reload).to have_attributes(full_name: "変更後", status: "left", left_on: Date.new(2026, 11, 1))
    end

    it "不正な値は422" do
      patch staff_member_path(staff), params: { staff_member: { status: "retired" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "更新では在留カードを追加・変更できない（nested は create のみ）" do
      expect do
        patch staff_member_path(staff), params: { staff_member: { full_name: "x", residence_cards_attributes: { "0" => { status_of_residence: "留学", card_number_last4: "ZZ00", expires_on: "2030-01-01" } } } }
      end.not_to change(ResidenceCard, :count)
    end

    it "更新すると audit_logs に update が、操作したユーザーつきで残る" do
      patch staff_member_path(staff), params: { staff_member: { full_name: "監査テスト" } }
      log = AuditLog.where(target_type: "StaffMember", target_id: staff.id, action: "update").last
      expect(log.user_id).to eq(admin.id)
      expect(log.organization_id).to eq(organization.id)
      expect(log.changes_json["full_name"]).to eq([ "変更前", "監査テスト" ])
    end
  end

  describe "削除" do
    it "スタッフの削除ルートは無い（退職は status の更新）" do
      staff = create(:staff_member, organization: organization)
      expect { delete staff_member_path(staff) }.not_to change(StaffMember, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
