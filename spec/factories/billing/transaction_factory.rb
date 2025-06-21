# frozen_string_literal: true

# == Schema Information
#
# Table name: transactions
#
#  id                 :integer          not null, primary key
#  account_id         :integer          not null
#  cluster_id         :integer          not null
#  code               :string(16)       not null
#  created_at         :datetime         not null
#  description        :string(255)      not null
#  incurred_on        :date             not null
#  quantity           :integer
#  statement_id       :integer
#  statementable_id   :integer
#  statementable_type :string(32)
#  unit_price         :decimal(10, 2)
#  updated_at         :datetime         not null
#  value              :decimal(10, 2)   not null
#
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
