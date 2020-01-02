# frozen_string_literal: true

FactoryBot.define do
  factory :group_membership, class: "Groups::Membership" do
    user
    group
    kind { "joiner" }
  end
end
