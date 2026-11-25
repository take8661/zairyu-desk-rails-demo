require "rails_helper"

RSpec.describe ExpiryAlertService do
  let(:organization) { create(:organization) }
  let(:today) { Date.new(2026, 11, 25) }

  def staff_expiring_in(days, **attrs)
    create(:staff_member, { organization: organization, expires_on: today + days }.merge(attrs))
  end

  describe "区分ごとの通知の作成" do
    {
      -1 => "expired",
      0 => "expiry_30",
      30 => "expiry_30",
      31 => "expiry_60",
      60 => "expiry_60",
      61 => "expiry_90",
      90 => "expiry_90"
    }.each do |days, kind|
      it "残日数#{days}日なら #{kind} を1件作る" do
        staff = staff_expiring_in(days)
        expect(described_class.call(organization.id, today: today)).to eq(1)
        notification = staff.notifications.sole
        expect(notification.kind).to eq(kind)
        expect(notification.notified_on).to eq(today)
        expect(notification.residence_card).to eq(staff.current_residence_card)
      end
    end

    it "残日数91日以上は通知しない" do
      staff_expiring_in(91)
      expect(described_class.call(organization.id, today: today)).to eq(0)
      expect(Notification.count).to eq(0)
    end

    it "その時点の最も厳しい区分の1件だけを作る（過去の緩い区分は遡って作らない）" do
      staff = staff_expiring_in(25)
      described_class.call(organization.id, today: today)
      expect(staff.notifications.pluck(:kind)).to eq([ "expiry_30" ])
    end

    it "日が進んで区分が厳しくなったら、新しい区分の通知を追加する" do
      staff = staff_expiring_in(61)
      described_class.call(organization.id, today: today)
      described_class.call(organization.id, today: today + 1)  # 残日数60 → expiry_60
      described_class.call(organization.id, today: today + 31) # 残日数30 → expiry_30
      expect(staff.notifications.order(:id).pluck(:kind)).to eq(%w[expiry_90 expiry_60 expiry_30])
    end
  end

  describe "冪等性" do
    it "同じ日に2回実行しても通知は増えない" do
      staff_expiring_in(10)
      staff_expiring_in(-3)
      staff_expiring_in(80)
      expect(described_class.call(organization.id, today: today)).to eq(3)
      expect { expect(described_class.call(organization.id, today: today)).to eq(0) }.not_to change(Notification, :count)
    end

    it "一意制約に当たった場合（RecordNotUnique）は握りつぶして次へ進む" do
      staff_expiring_in(10)
      other = staff_expiring_in(11)
      calls = 0
      allow(Notification).to receive(:create!).and_wrap_original do |original, **attrs|
        calls += 1
        raise ActiveRecord::RecordNotUnique, "duplicate" if calls == 1

        original.call(**attrs)
      end
      expect(described_class.call(organization.id, today: today)).to eq(1)
      expect(other.notifications.count + Notification.count).to be >= 1
    end
  end

  describe "対象の絞り込み" do
    it "退職者は対象外" do
      create(:staff_member, :left, organization: organization, expires_on: today + 5)
      expect(described_class.call(organization.id, today: today)).to eq(0)
    end

    it "current の在留カードだけを見る（古い履歴は見ない）" do
      staff = staff_expiring_in(5)
      create(:residence_card, staff_member: staff, expires_on: today + 400)
      expect(described_class.call(organization.id, today: today)).to eq(0)
    end

    it "organization_id を渡すとその組織だけ、nil なら全組織" do
      other_org = create(:organization)
      staff_expiring_in(5)
      create(:staff_member, organization: other_org, expires_on: today + 5)
      expect(described_class.call(organization.id, today: today)).to eq(1)
      expect(described_class.call(nil, today: today)).to eq(1) # 自組織は作成済み、残りの1組織分
      expect(Notification.count).to eq(2)
    end
  end

  describe "通知の内容" do
    it "メッセージと送信予定メール（デモ表示）の件名・本文を作る（在留カード番号は含めない）" do
      staff = staff_expiring_in(10, full_name: "山田太郎")
      described_class.call(organization.id, today: today)
      notification = staff.notifications.sole
      expect(notification.message).to eq("山田太郎さんの在留期間があと10日です")
      expect(notification.mail_subject).to include("【在留期限のお知らせ（デモ）】", "山田太郎")
      expect(notification.mail_body).to include(organization.name, "デモ")
      expect(notification.mail_body).not_to include("AB12")
    end

    it "期限切れは「N日前に終了しています」" do
      staff = staff_expiring_in(-3, full_name: "佐藤花子")
      described_class.call(organization.id, today: today)
      expect(staff.notifications.sole.message).to eq("佐藤花子さんの在留期間が3日前に終了しています")
    end
  end
end
