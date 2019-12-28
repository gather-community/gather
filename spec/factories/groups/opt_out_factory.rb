# frozen_string_literal: true

FactoryBot.define do
  factory :group_opt_out, class: "Groups::OptOut" do
    group
    user
  end
end
