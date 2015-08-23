FactoryGirl.define do
  factory :community do
    sequence(:name){ |n| "Community #{n}" }
    sequence(:abbrv){ |n| "C#{n}" }
  end
end