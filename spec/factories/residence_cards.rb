FactoryBot.define do
  factory :residence_card do
    staff_member
    organization { staff_member.organization }
    status_of_residence { "特定技能1号" }
    card_number_last4 { "CD34" }
    issued_on { nil }
    expires_on { Date.current + 365 }
    permission_for_activity { false }
  end
end
