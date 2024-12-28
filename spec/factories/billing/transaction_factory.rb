# frozen_string_literal: true

FactoryBot.define do
  factory :transaction, class: "Billing::Transaction" do
    incurred_on { "2015-10-18" }
    code { "othchg" }
    description { "Some stuff" }
    value { "9.99" }
    account
  end

  factory :meal_transaction, class: "Billing::Transaction" do
    incurred_on { "2015-10-18" }
    code { "meal" }
    description { "Yummy meal" }
    value { "9.99" }
    account
  end
end
