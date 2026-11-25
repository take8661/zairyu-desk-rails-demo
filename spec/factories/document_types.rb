FactoryBot.define do
  factory :document_type do
    organization
    sequence(:name) { |n| "テスト書類種別#{n}" }
    required { true }
    renew_interval_months { nil }
  end
end
