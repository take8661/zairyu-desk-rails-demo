FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "テスト組織#{n}（架空）" }
    sequence(:slug) { |n| "test-org-#{n}" }
  end
end
