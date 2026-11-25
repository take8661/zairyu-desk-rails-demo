require "rails_helper"

RSpec.describe "ダッシュボード" do
  let(:organization) { create(:organization) }
  let!(:user) { create(:user, organization: organization) }
  let!(:doc_required) { create(:document_type, organization: organization, name: "必須書類", required: true) }
  let!(:doc_optional) { create(:document_type, organization: organization, name: "任意書類", required: false) }

  before { sign_in_as(user) }

  def metric_value(label)
    response.body[/#{Regexp.escape(label)}<\/div>\s*<div class="value">(\d+)/, 1].to_i
  end

  it "指標：期限90日以内・期限切れ・書類未提出・書類期限切れ（定義どおり）" do
    create(:staff_member, organization: organization, expires_on: Date.current)         # 当日 → 90日以内
    create(:staff_member, organization: organization, expires_on: Date.current + 90)    # 90日目 → 含む
    create(:staff_member, organization: organization, expires_on: Date.current + 91)    # 91日 → 含まない
    create(:staff_member, organization: organization, expires_on: Date.current - 1)     # 期限切れ
    create(:staff_member, :left, organization: organization, expires_on: Date.current - 30) # 退職者は除く

    get root_path
    expect(response).to have_http_status(:ok)
    expect(metric_value("在留期限が90日以内")).to eq(2)
    expect(metric_value("在留期限切れ")).to eq(1)
    # 在籍4名の必須書類（missing）4件。任意書類・退職者は数えない
    expect(metric_value("必須書類の未提出")).to eq(4)
  end

  it "書類期限切れは必須書類の expired だけを数える" do
    staff = create(:staff_member, organization: organization)
    staff.staff_documents.find_by!(document_type: doc_required).update_columns(state: "expired")
    staff.staff_documents.find_by!(document_type: doc_optional).update_columns(state: "expired")
    get root_path
    expect(metric_value("書類の有効期限切れ")).to eq(1)
  end

  it "期限の近い順の一覧：期限切れと90日以内のみ、期限の昇順（同日は社員コード）、区分バッジに文字ラベルを併記" do
    create(:staff_member, organization: organization, employee_code: "B-2", full_name: "同日の人2", expires_on: Date.current + 40)
    create(:staff_member, organization: organization, employee_code: "A-1", full_name: "同日の人1", expires_on: Date.current + 40)
    create(:staff_member, organization: organization, employee_code: "C-3", full_name: "期限切れの人", expires_on: Date.current - 2)
    create(:staff_member, organization: organization, employee_code: "D-4", full_name: "90日目の人", expires_on: Date.current + 90)
    create(:staff_member, organization: organization, employee_code: "E-5", full_name: "ずっと先の人", expires_on: Date.current + 365)

    get root_path
    body = response.body
    names = [ "期限切れの人", "同日の人1", "同日の人2", "90日目の人" ]
    positions = names.map { |name| body.index(name) }
    expect(positions).to eq(positions.sort)
    expect(positions).to all(be_present)
    expect(body).not_to include("ずっと先の人")
    expect(body).to include("期限切れ", "60日以内", "90日以内")
    expect(body).to include("2日超過", "あと40日")
  end

  it "対象がいないときは空状態のメッセージを出す" do
    get root_path
    expect(response.body).to include("在留期限が90日以内のスタッフはいません")
  end

  it "在留カードが無いスタッフ（異常データ）がいても落ちない" do
    staff = create(:staff_member, organization: organization)
    ResidenceCard.where(staff_member_id: staff.id).delete_all
    get root_path
    expect(response).to have_http_status(:ok)
  end

  it "ナビと「架空のデータによるデモです」を表示する" do
    get root_path
    expect(response.body).to include("架空のデータによるデモです", "ダッシュボード", "スタッフ", "通知", "出力")
    expect(response.body).not_to include("設定") # member には設定メニューを出さない
  end
end
