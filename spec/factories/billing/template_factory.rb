# frozen_string_literal: true

FactoryBot.define do
  factory :billing_template, class: "Billing::Template" do
    community { Defaults.community }
    description { "MyString" }
    code { "othchg" }
    value { "9.99" }
  end
end
