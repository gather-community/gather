# frozen_string_literal: true

FactoryBot.define do
  factory :feature_flag do
    sequence(:name) { |i| "FF #{i}" }
  end
end
