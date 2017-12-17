def default_community
  Community.first || create(:community)
end

FactoryBot.define do
  factory :community do
    sequence(:name) { |n| "Community #{n}" }
    sequence(:abbrv) { |n| "C#{n%10}" }
    sequence(:slug) { |n| "community#{n}" }
  end
end
