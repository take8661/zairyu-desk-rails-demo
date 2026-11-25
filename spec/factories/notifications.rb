FactoryBot.define do
  factory :notification do
    staff_member
    organization { staff_member.organization }
    residence_card { staff_member.current_residence_card }
    kind { "expiry_30" }
    notified_on { Date.current }
    message { "テストさんの在留期間があと10日です" }
    mail_subject { "【在留期限のお知らせ（デモ）】テストさんの在留期間があと10日です" }
    mail_body { "デモ用の本文です。" }
  end
end
