# frozen_string_literal: true

FactoryBot.define do
  factory :domain do
    sequence(:name) { |i| "domain#{i}.example.com" }

    after(:build) do |domain|
      domain.communities << Defaults.community if domain.communities.none?
    end
  end
end
