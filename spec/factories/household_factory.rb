FactoryGirl.define do
  factory :household do
    transient do
      with_members true
    end

    sequence(:name){ |n| "Household#{n}" }
    community { default_community }

    # NOTE: Don't try to assign FactoryGirl created users directly to households as they already
    # have households and it doesn't work. Instead, create households first and then assign them to users.
    after(:create) do |household, evaluator|
      if household.users.empty? && evaluator.with_members
        household.users << create(:user, household: household)
      end
    end
  end
end
