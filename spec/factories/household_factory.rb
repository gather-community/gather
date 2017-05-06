FactoryGirl.define do
  factory :household do
    transient do
      with_members true
    end

    sequence(:name){ |n| "Household#{n}" }
    community { default_community }

    after(:create) do |household, evaluator|
      if household.users.empty? && evaluator.with_members
        household.users << create(:user, household: household)
      end
    end
  end
end
