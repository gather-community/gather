FactoryGirl.define do
  factory :household do
    sequence(:name){ |n| "Household#{n}" }
    community
  end
end