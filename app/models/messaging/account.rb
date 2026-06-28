# frozen_string_literal: true

# == Schema Information
#
# Table name: messaging_accounts
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  currency     :string(3)        not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
module Messaging
  # Holds a community's messaging (e.g. SMS) balance. Created on demand the first time a
  # community tops up; funded via Stripe top-up transactions (see Stripe::TopupProcessor).
  class Account < ApplicationRecord
    acts_as_tenant :cluster

    # The Stripe product whose purchase tops up a messaging account. IDs differ between
    # Stripe test and live mode, so they're sourced from Settings rather than hard-coded.
    PRODUCT_ID = Settings.stripe.messaging&.topup_product_id

    belongs_to :community
    has_many :transactions, dependent: :destroy

    validates :currency, presence: true

    def balance_cents
      transactions.sum(:amount_cents)
    end

    def balance
      Money.new(balance_cents, currency)
    end
  end
end
