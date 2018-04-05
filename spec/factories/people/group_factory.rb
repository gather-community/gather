FactoryBot.define do
  factory :people_group, class: "People::Group" do
    sequence(:name) { |n| "Group #{n}" }
    community { default_community }
  end
end
