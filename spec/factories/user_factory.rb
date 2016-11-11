FactoryGirl.define do
  factory :user do
    first_name "John"
    last_name  "Doe"
    sequence(:email){ |n| "person#{n}@example.com" }
    sequence(:google_email){ |n| "person#{n}@gmail.com" }
    mobile_phone "5555551212"
    association :household, with_members: false # Don't want to create extra users.

    %i(admin cluster_admin super_admin biller).each do |role|
      factory role do
        after(:create) do |user|
          user.add_role(role)
        end
      end
    end
  end
end