# frozen_string_literal: true

FactoryBot.define do
  factory :people_group, class: "People::Group" do
    sequence(:name) { |n| "Group #{n}" }
    community { Defaults.community }
  end
end
