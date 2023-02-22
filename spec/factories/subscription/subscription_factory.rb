# frozen_string_literal: true

FactoryBot.define do
  factory :subscription, class: "Subscription::Subscription" do
    community
    stripe_id { "sub_1234" }
  end
end
