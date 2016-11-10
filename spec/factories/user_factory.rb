FactoryGirl.define do
  factory :user do
    first_name "John"
    last_name  "Doe"
    sequence(:email){ |n| "person#{n}@example.com" }
    sequence(:google_email){ |n| "person#{n}@gmail.com" }
    mobile_phone "5555551212"
    association :household, with_members: false # Don't want to create extra users.

    factory :admin do
      after(:create) do |user|
        user.add_role(:admin)
      end
    end

    factory :biller do
      after(:create) do |user|
        user.add_role(:biller)
      end
    end
  end
end