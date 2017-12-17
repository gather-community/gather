def default_cluster
  @default_cluster ||= Cluster.find_by(name: "Default")
end

FactoryBot.define do
  factory :cluster do
    sequence(:name) { |n| "Cluster #{n}" }
  end
end
