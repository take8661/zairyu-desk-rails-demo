FactoryBot.define do
  factory :user do
    organization
    sequence(:email_address) { |n| "user#{n}@test.example" }
    password { AuthHelpers.test_credential }
    role { "member" }

    trait :admin do
      role { "admin" }
    end
  end
end
