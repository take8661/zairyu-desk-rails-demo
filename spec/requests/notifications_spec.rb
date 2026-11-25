require "rails_helper"

RSpec.describe "通知" do
  let(:organization) { create(:organization) }
  let!(:user) { create(:user, organization: organization) }

  before { sign_in_as(user) }

  it "通知が無いときは空状態のメッセージ" do
    get notifications_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("通知はまだありません")
  end

  it "ExpiryAlertService が作った通知と、送信予定メール（デモ表示）の件名・本文を新しい順に表示する" do
    old_staff = create(:staff_member, organization: organization, full_name: "古い通知の人", expires_on: Date.current + 50)
    ExpiryAlertService.call(organization.id, today: Date.current - 3)
    Notification.where(staff_member: old_staff).update_all(notified_on: Date.current - 3)
    create(:staff_member, organization: organization, full_name: "新しい通知の人", expires_on: Date.current + 5)
    ExpiryAlertService.call(organization.id)

    get notifications_path
    body = response.body
    expect(body).to include("送信予定メール（デモ表示）", "【在留期限のお知らせ（デモ）】")
    expect(body).to include("新しい通知の人さんの在留期間があと5日です")
    expect(body.index("新しい通知の人")).to be < body.index("古い通知の人")
    expect(body).to include("このメールは送信されません")
  end

  it "メールは実際には送信しない（メーラーが存在しない）" do
    expect(defined?(ActionMailer)).to be_nil
  end
end
