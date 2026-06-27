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
  # community tops up; funded via Stripe top-up transactions (see StripeTopupProcessor).
  class Account < ApplicationRecord
    acts_as_tenant :cluster

    # Maps an ISO 3166-1 alpha-2 country code (uppercase) to its default ISO 4217 currency
    # (lowercase, to match Stripe and the money gem). Covers Stripe-supported countries;
    # extend as Stripe adds markets. Source: https://stripe.com/global
    COUNTRY_CURRENCIES = {
      "AE" => "aed", "AT" => "eur", "AU" => "aud", "BE" => "eur", "BG" => "bgn",
      "BR" => "brl", "CA" => "cad", "CH" => "chf", "CY" => "eur", "CZ" => "czk",
      "DE" => "eur", "DK" => "dkk", "EE" => "eur", "ES" => "eur", "FI" => "eur",
      "FR" => "eur", "GB" => "gbp", "GI" => "gbp", "GR" => "eur", "HK" => "hkd",
      "HR" => "eur", "HU" => "huf", "ID" => "idr", "IE" => "eur", "IN" => "inr",
      "IT" => "eur", "JP" => "jpy", "LI" => "chf", "LT" => "eur", "LU" => "eur",
      "LV" => "eur", "MT" => "eur", "MX" => "mxn", "MY" => "myr", "NL" => "eur",
      "NO" => "nok", "NZ" => "nzd", "PL" => "pln", "PT" => "eur", "RO" => "ron",
      "SE" => "sek", "SG" => "sgd", "SI" => "eur", "SK" => "eur", "TH" => "thb",
      "US" => "usd"
    }.freeze

    # The Stripe product whose purchase tops up a messaging account. IDs differ between
    # Stripe test and live mode, so they're sourced from Settings rather than hard-coded.
    PRODUCT_ID = Settings.stripe.messaging&.topup_product_id

    belongs_to :community
    has_many :transactions, dependent: :destroy

    validates :currency, presence: true

    # Returns the default currency for the community's country, or nil if unsupported.
    def self.currency_for(community)
      COUNTRY_CURRENCIES[community.country_code]
    end

    def balance_cents
      transactions.sum(:amount_cents)
    end

    def balance
      Money.new(balance_cents, currency)
    end
  end
end
