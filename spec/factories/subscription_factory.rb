# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    transient do
      is_setup { true }
    end

    community
    stripe_id { is_setup ? "sub_1234" : nil }
    initial_contact_email { is_setup ? nil : "person@example.com" }
    initial_price_id { is_setup ? nil : "price_1234" }
    initial_seats { is_setup ? nil : 10 }
  end
end
