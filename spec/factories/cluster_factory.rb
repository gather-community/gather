FactoryBot.define do
  factory :cluster do
    sequence(:name) { |n| "Cluster #{n}" }
  end
end
