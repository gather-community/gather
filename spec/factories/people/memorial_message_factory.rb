# frozen_string_literal: true

FactoryBot.define do
  factory :memorial_message, class: "People::MemorialMessage" do
    memorial
    association(:author, factory: :user)
    body { "A message" }
  end
end
