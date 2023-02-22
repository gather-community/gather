# frozen_string_literal: true

FactoryBot.define do
  factory :subscription_intent, class: "Subscription::Intent" do
    community
    contact_email { "person@example.com" }
    currency { "usd" }
    months_per_period { 3 }
    price_per_user_cents { 200 }
    quantity { 10 }
    start_date { Time.zone.today - 2 }
    address_line1 { "123 Little Pond Rd" }
    address_city { "Ann Arbor" }
    address_country { "US" }
    payment_method_types { %w[us_bank_account card] }
    tier { "standard" }
  end
end
