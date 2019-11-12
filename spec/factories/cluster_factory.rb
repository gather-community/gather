# frozen_string_literal: true

FactoryBot.define do
  factory :cluster do
    sequence(:name) { |n| "Cluster #{n}" }
  end
end
