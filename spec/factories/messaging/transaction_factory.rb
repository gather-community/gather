# frozen_string_literal: true

# == Schema Information
#
# Table name: messaging_transactions
#
#  id                          :bigint           not null, primary key
#  account_id                  :bigint           not null
#  amount_cents                :integer          not null
#  cluster_id                  :bigint           not null
#  created_at                  :datetime         not null
#  creator_id                  :bigint
#  description                 :string(255)      not null
#  stripe_invoice_line_item_id :string
#  updated_at                  :datetime         not null
#
FactoryBot.define do
  factory :messaging_transaction, class: "Messaging::Transaction" do
    account factory: :messaging_account
    description { "Messaging bundle top-up" }
    amount_cents { 1000 }
  end
end
