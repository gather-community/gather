FactoryGirl.define do
  factory :user do
    first_name "John"
    last_name  "Doe"
    admin false
    sequence(:email){ |n| "person#{n}@example.com" }
    sequence(:google_email){ |n| "person#{n}@gmail.com" }
    household
    mobile_phone "5555551212"
  end
end