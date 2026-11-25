require "rails_helper"

# system spec（rack_test。JS不要の画面）：
# ログイン → スタッフ登録（在留カード付き）→ 書類を submitted → approved に更新 → PDF出力 の一連
RSpec.describe "スタッフ登録から書類承認・PDF出力までの一連の操作", type: :system do
  let(:organization) { create(:organization, name: "システムテスト製作所") }
  let!(:admin) { create(:user, :admin, organization: organization, email_address: "flow@test.example") }
  let!(:doc_type) { create(:document_type, organization: organization, name: "雇用契約書", renew_interval_months: 12) }

  it "一連の操作が通る" do
    sign_in_through_form(admin)
    expect(page).to have_content("ダッシュボード")
    expect(page).to have_content("架空のデータによるデモです")

    click_link "スタッフ"
    click_link "スタッフを登録"
    fill_in "社員コード（必須）", with: "SYS-001"
    fill_in "氏名（必須）", with: "山田 太郎"
    fill_in "氏名（カナ）", with: "ヤマダ タロウ"
    fill_in "生年月日（必須）", with: "1996-02-03"
    fill_in "国籍（必須）", with: "ベトナム"
    select "ベトナム語", from: "連絡に使う言語"
    fill_in "雇用開始日（必須）", with: "2025-04-01"
    select "特定技能1号", from: "在留資格（必須）"
    fill_in "カード番号の下4桁（英数字）", with: "ab12"
    fill_in "在留期間満了日（必須）", with: (Date.current + 25).to_s
    click_button "登録する"

    expect(page).to have_content("スタッフを登録しました")
    expect(page).to have_content("山田 太郎")
    expect(page).to have_content("AB12")
    expect(page).not_to have_content("ab12")

    click_link "書類チェックリスト"
    staff = organization.staff_members.find_by!(employee_code: "SYS-001")
    document = staff.staff_documents.find_by!(document_type: doc_type)
    expect(page).to have_content("未提出")

    within("#document_#{document.id}") do
      select "提出済み（確認待ち）", from: "state_#{document.id}"
      fill_in "submitted_on_#{document.id}", with: "2026-11-01"
      click_button "更新"
    end
    expect(page).to have_content("「雇用契約書」を更新しました")
    expect(document.reload.state).to eq("submitted")
    expect(document.expires_on).to eq(Date.new(2027, 11, 1))

    within("#document_#{document.id}") do
      select "承認済み", from: "state_#{document.id}"
      click_button "更新"
    end
    expect(document.reload.state).to eq("approved")

    # 許可されない遷移（承認済み→未提出）は画面にエラーが出る
    within("#document_#{document.id}") do
      select "未提出", from: "state_#{document.id}"
      click_button "更新"
    end
    expect(page).to have_content("へは変更できません")
    expect(document.reload.state).to eq("approved")

    visit expiry_list_report_path(format: :pdf)
    expect(page.response_headers["Content-Type"]).to include("application/pdf")
    text = PDF::Reader.new(StringIO.new(page.body)).pages.map(&:text).join("\n")
    expect(text).to include("山田 太郎", "SYS-001")
  end

  it "ダッシュボードで期限の近いスタッフが一目で分かる" do
    create(:staff_member, organization: organization, full_name: "期限間近 花子", expires_on: Date.current + 7)
    sign_in_through_form(admin)
    expect(page).to have_content("期限間近 花子")
    expect(page).to have_content("30日以内")
    expect(page).to have_content("あと7日")
  end

  it "管理者は設定画面から「今すぐ実行」できる" do
    create(:staff_member, organization: organization, expires_on: Date.current + 7)
    sign_in_through_form(admin)
    click_link "設定"
    click_button "今すぐ実行"
    expect(page).to have_content("新規通知 1件")
    click_link "通知"
    expect(page).to have_content("送信予定メール（デモ表示）")
  end

  it "担当者（member）には設定メニューが出ない" do
    member = create(:user, organization: organization, email_address: "member-flow@test.example")
    sign_in_through_form(member)
    expect(page).not_to have_link("設定")
    visit settings_users_path
    expect(page).to have_content("権限がありません")
  end
end
