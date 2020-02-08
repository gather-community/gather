# frozen_string_literal: true

FactoryBot.define do
  factory :group_mailman_list, class: "Groups::Mailman::List" do
    group
    sequence(:name) { |i| "list#{i}" }
    sequence(:mailman_id) { |i| "list#{i}.something.gather.coop" }
    outside_members { "foo@example.com" }
    outside_senders { "bar@example.com" }
    domain
  end
end
