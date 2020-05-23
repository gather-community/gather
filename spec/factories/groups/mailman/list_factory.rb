# frozen_string_literal: true

FactoryBot.define do
  factory :group_mailman_list, class: "Groups::Mailman::List" do
    group
    sequence(:name) { |i| "list#{i}" }
    remote_id { nil }
    domain
  end
end
