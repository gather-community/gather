# frozen_string_literal: true

FactoryBot.define do
  factory :communities_signup, class: "Communities::Signup" do
    sequence(:community_name) { |n| "Test Community #{n}" }
    sequence(:slug) { |n| "test-community-#{n}" }
    contact_first_name { Faker::Name.first_name }
    contact_last_name { Faker::Name.last_name }
    contact_email { "person#{rand(10_000_000..99_999_999)}@example.com" }
    country_code { "US" }
    time_zone { "Eastern Time (US & Canada)" }
    introduction { "We are a cohousing community. https://example.com" }
    want_sample_data { false }
    status { "pending" }

    trait :approved do
      status { "approved" }
      reviewed_at { Time.current }
      message { "Welcome! We're excited to have you on board." }
    end

    trait :denied do
      status { "denied" }
      reviewed_at { Time.current }
      message { "Does not meet criteria." }
    end
  end
end
