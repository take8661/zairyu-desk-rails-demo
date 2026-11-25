FactoryBot.define do
  factory :staff_member do
    organization
    sequence(:employee_code) { |n| "T-#{n.to_s.rjust(3, '0')}" }
    sequence(:full_name) { |n| "テスト太郎#{n}" }
    full_name_kana { "テストタロウ" }
    birth_on { Date.new(1995, 4, 1) }
    nationality { "ベトナム" }
    preferred_language { "vi" }
    hired_on { Date.new(2024, 4, 1) }
    status { "active" }
    job_title { "製造スタッフ" }
    workplace { "本社工場" }
    hourly_wage_yen { 1200 }
    weekly_hours { 40.0 }

    transient do
      # 最初の在留カードの期限（作成時に在留カードが最低1枚必要なため）
      expires_on { Date.current + 200 }
      status_of_residence { "特定技能1号" }
    end

    after(:build) do |staff, evaluator|
      if staff.residence_cards.empty?
        staff.residence_cards.build(
          organization: staff.organization,
          status_of_residence: evaluator.status_of_residence,
          card_number_last4: "AB12",
          expires_on: evaluator.expires_on
        )
      end
    end

    trait :left do
      status { "left" }
      left_on { Date.current - 30 }
    end
  end
end
