FactoryGirl.define do
  factory :household do
    sequence(:name){ |n| "Household#{n}" }
    community { default_community }

    after(:create) do |household|
      household.users << create(:user, household: household)
    end
  end
end