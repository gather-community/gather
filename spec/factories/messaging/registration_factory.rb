# frozen_string_literal: true

FactoryBot.define do
  factory :messaging_registration, class: "Messaging::Registration" do
    community { Defaults.community }
    status { "draft" }
    legal_name { "Sunny Hill Cohousing Association" }
    display_name { "Sunny Hill Cohousing" }
    entity_type { "NON_PROFIT" }
    ein { "12-3456789" }
    street { "1 Main St" }
    city { "Ithaca" }
    state { "NY" }
    postal_code { "14850" }
    email { "admin@example.com" }
    phone { "+16075551234" }
    website { "https://sunnyhill.example.com" }

    # Setup paid and the brand submitted to Telnyx.
    trait :paid do
      status { "brand_pending" }
      stripe_invoice_id { "in_setup_#{SecureRandom.hex(4)}" }
      paid_at { Time.current }
      submitted_at { Time.current }
      telnyx_brand_id { "brand-#{SecureRandom.hex(4)}" }
    end
  end
end
