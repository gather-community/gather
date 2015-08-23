FactoryGirl.define do
  factory :location do
    sequence(:name){ |n| "Location #{n}" }
    sequence(:abbrv){ |n| "Loc#{n}" }
  end
end