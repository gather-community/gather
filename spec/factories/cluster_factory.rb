def default_cluster
  Cluster.first || create(:cluster)
end

FactoryGirl.define do
  factory :cluster do
    sequence(:name) { |n| "Cluster #{n}" }
  end
end
