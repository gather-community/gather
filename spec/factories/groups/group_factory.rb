# frozen_string_literal: true

FactoryBot.define do
  factory :group, class: "Groups::Group" do
    sequence(:name) { |n| "Group #{n}" }
    community { Defaults.community }
  end
end
