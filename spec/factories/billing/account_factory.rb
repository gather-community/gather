# frozen_string_literal: true

FactoryBot.define do
  factory :account, class: "Billing::Account" do
    household factory: :household, skip_listener_action: :account_create
    community { Defaults.community }
    last_statement_on { "2015-10-27" }
    due_last_statement { "8.81" }
    total_new_credits { "10.99" }
    total_new_charges { "22.71" }

    trait :no_activity do
      last_statement_on { nil }
      due_last_statement { nil }
      total_new_credits { 0.0 }
      total_new_charges { 0.0 }
      balance_due { 0.0 }
      current_balance { 0.0 }
    end

    trait :with_statement do
      after(:create) do |account|
        account.transactions << create(:transaction, account: account, incurred_on: Time.zone.today - 10.days)
        account.transactions << create(:transaction, account: account, incurred_on: Time.zone.today - 7.days)
        Timecop.freeze(-3.days) { Billing::Statement.new(account: account, prev_balance: 0).populate! }
      end
    end

    trait :with_transactions do
      after(:create) do |account|
        account.transactions << create(:transaction, account: account, incurred_on: Time.zone.today - 2.days)
        account.transactions << create(:transaction, account: account, incurred_on: Time.zone.today - 1.day)
      end
    end
  end
end
