require "rails_helper"

# 画面ごとの権限（権限表の全行）：admin／member／未ログイン
RSpec.describe "画面ごとの権限" do
  include_context "two organizations"

  # [説明, HTTPメソッド, パスを返す lambda, admin の期待, member の期待]
  let(:rows) do
    [
      [ "ダッシュボード", :get, -> { root_path }, :ok, :ok ],
      [ "スタッフ一覧", :get, -> { staff_members_path }, :ok, :ok ],
      [ "スタッフ詳細", :get, -> { staff_member_path(staff_a) }, :ok, :ok ],
      [ "スタッフ登録フォーム", :get, -> { new_staff_member_path }, :ok, :ok ],
      [ "スタッフ編集フォーム", :get, -> { edit_staff_member_path(staff_a) }, :ok, :ok ],
      [ "在留カード追加フォーム", :get, -> { new_staff_member_residence_card_path(staff_a) }, :ok, :ok ],
      [ "書類チェックリスト", :get, -> { staff_member_staff_documents_path(staff_a) }, :ok, :ok ],
      [ "通知一覧", :get, -> { notifications_path }, :ok, :ok ],
      [ "出力ページ", :get, -> { reports_path }, :ok, :ok ],
      [ "在留期限一覧PDF", :get, -> { expiry_list_report_path(format: :pdf) }, :ok, :ok ],
      [ "提出用CSV", :get, -> { staff_report_path(format: :csv) }, :ok, :forbidden ],
      [ "組織設定", :get, -> { settings_organization_path }, :ok, :forbidden ],
      [ "組織名の編集", :get, -> { edit_settings_organization_path }, :ok, :forbidden ],
      [ "ユーザー管理", :get, -> { settings_users_path }, :ok, :forbidden ],
      [ "ユーザー追加フォーム", :get, -> { new_settings_user_path }, :ok, :forbidden ],
      [ "書類種別", :get, -> { settings_document_types_path }, :ok, :forbidden ],
      [ "書類種別追加フォーム", :get, -> { new_settings_document_type_path }, :ok, :forbidden ],
      [ "ジョブ今すぐ実行", :post, -> { settings_run_jobs_path }, :see_other, :forbidden ]
    ]
  end

  it "admin は表のとおりの結果になる" do
    sign_in_as(admin_a)
    rows.each do |name, verb, path, admin_expected, _member_expected|
      public_send(verb, instance_exec(&path))
      expect(response).to have_http_status(admin_expected), "admin／#{name}：期待 #{admin_expected}、実際 #{response.status}"
    end
  end

  it "member は表のとおりの結果になる（管理画面・CSV・ジョブ実行は403）" do
    sign_in_as(member_a)
    rows.each do |name, verb, path, _admin_expected, member_expected|
      public_send(verb, instance_exec(&path))
      expect(response).to have_http_status(member_expected), "member／#{name}：期待 #{member_expected}、実際 #{response.status}"
    end
  end

  it "未ログインは（ログイン画面と /up を除く）全画面でログイン画面へ302" do
    rows.each do |name, verb, path, *|
      public_send(verb, instance_exec(&path))
      expect(response).to have_http_status(:found), "未ログイン／#{name}：期待 302、実際 #{response.status}"
      expect(response).to redirect_to(new_session_path)
    end
  end

  it "member の403は自組織の画面なので404ではなく、日本語の403画面になる" do
    sign_in_as(member_a)
    get settings_users_path
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include("403", "権限がありません")
  end

  it "member はユーザーの追加・書類種別の追加・組織名の変更を実行できない（403で何も変わらない）" do
    sign_in_as(member_a)
    expect { post settings_users_path, params: { user: { email_address: "x@test.example", role: "admin", password: "password-xyz" } } }
      .not_to change(User, :count)
    expect(response).to have_http_status(:forbidden)
    expect { post settings_document_types_path, params: { document_type: { name: "不正追加" } } }.not_to change(DocumentType, :count)
    expect(response).to have_http_status(:forbidden)
    patch settings_organization_path, params: { organization: { name: "乗っ取り" } }
    expect(response).to have_http_status(:forbidden)
    expect(org_a.reload.name).to eq("組織A（テスト）")
  end

  it "member でもスタッフの登録・書類の更新ができる" do
    sign_in_as(member_a)
    expect do
      post staff_members_path, params: { staff_member: {
        employee_code: "M-1", full_name: "担当者登録", birth_on: "1995-01-01", nationality: "ベトナム", hired_on: "2025-04-01",
        residence_cards_attributes: { "0" => { status_of_residence: "留学", card_number_last4: "ZZ99", expires_on: "2027-01-01" } }
      } }
    end.to change { org_a.staff_members.count }.by(1)
    expect(response).to have_http_status(:found)
  end
end
