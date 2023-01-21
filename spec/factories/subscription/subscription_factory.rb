# frozen_string_literal: true

FactoryBot.define do
  factory :subscription, class: "Subscription::Subscription" do
    transient do
      is_registered { true }
    end

    community
    stripe_id { is_registered ? "sub_1234" : nil }
    contact_email { is_registered ? nil : "person@example.com" }
    currency { is_registered ? nil : "USD" }
    months_per_period { is_registered ? nil : 3 }
    price_per_user { is_registered ? nil : 2.00 }
    quantity { is_registered ? nil : 10 }
    start_date { is_registered ? nil : Date.today - 2 }
  end
end
