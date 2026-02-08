# frozen_string_literal: true

# == Schema Information
#
# Table name: accounts
#
#  id                 :integer          not null, primary key
#  balance_due        :decimal(10, 2)   default(0.0), not null
#  cluster_id         :integer          not null
#  community_id       :integer          not null
#  created_at         :datetime         not null
#  credit_limit       :decimal(10, 2)
#  current_balance    :decimal(10, 2)   default(0.0), not null
#  due_last_statement :decimal(10, 2)
#  household_id       :integer          not null
#  last_statement_id  :integer
#  last_statement_on  :date
#  total_new_charges  :decimal(10, 2)   default(0.0), not null
#  total_new_credits  :decimal(10, 2)   default(0.0), not null
#  updated_at         :datetime         not null
#
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
