# frozen_string_literal: true

module Billing
  # Models a transaction in a billing account.
  class Transaction < ApplicationRecord
    include Transactable

    DESCRIPTION_MAX_LENGTH = 255

    acts_as_tenant :cluster

    self.table_name = "transactions"

    belongs_to :account
    belongs_to :statement
    belongs_to :statementable, polymorphic: true

    scope :in_community, ->(c) { joins(:account).merge(Billing::Account.in_community(c)) }
    scope :for_household, ->(h) { joins(account: :household).where("households.id = ?", h.id) }
    scope :for_community_or_household,
      ->(c, h) { joins(:account).merge(Billing::Account.for_community_or_household(c, h)) }
    scope :incurred_between, ->(a, b) { where("incurred_on >= ? AND incurred_on <= ?", a, b) }
    scope :recorded_between,
      ->(a, b) { where("transactions.created_at >= ? AND transactions.created_at <= ?", a, b) }
    scope :no_statement, -> { where(statement_id: nil) }
    scope :newest_first, -> { order(incurred_on: :desc, created_at: :desc) }
    scope :oldest_first, -> { order(:incurred_on, :created_at) }

    delegate :household, :household_id, :community_id, :community, to: :account
    delegate :effect, to: :type

    before_validation do
      # Respect qty and unit price
      self.value = quantity * unit_price if quantity.present? && unit_price.present?
    end

    after_create do
      account.transaction_added!(self)
    end

    after_destroy do
      account.recalculate! if statement_id.nil?
    end

    validates :incurred_on, presence: true
    validate :quantity_and_unit_price

    def self.date_range(account: nil, community: nil)
      txns = all
      txns = txns.where(account: account) unless account.nil?
      txns = txns.in_community(community) unless community.nil?
      return nil if txns.none?
      [
        [txns.minimum(:created_at).to_date, txns.minimum(:incurred_on)].min,
        [txns.maximum(:created_at).to_date, txns.maximum(:incurred_on)].max
      ]
    end

    # Used only for CSV
    def chg_crd
      increaser? ? "charge" : "credit"
    end

    def meal_id
      (statementable_type == "Meals::Meal") ? statementable_id : nil
    end

    def statement?
      !statement_id.nil?
    end

    private

    def quantity_and_unit_price
      if quantity.present? && unit_price.blank?
        errors.add(:unit_price, "can't be blank if quantity is present")
      elsif quantity.blank? && unit_price.present?
        errors.add(:quantity, "can't be blank if unit price is present")
      end
    end
  end
end
