# frozen_string_literal: true

FactoryBot.define do
  factory :transaction, class: "Billing::Transaction" do
    incurred_on { "2015-10-18" }
    code { "othchg" }
    description { "Some stuff" }
    value { "9.99" }
    account

    factory :credit do
      code { "payment" }
      value { "-9.99" }
    end

    factory :charge do
    end
  end
end
