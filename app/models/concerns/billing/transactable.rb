# frozen_string_literal: true

module Billing
  # Things common to transactions and templates.
  module Transactable
    extend ActiveSupport::Concern

    TYPES = [
      OpenStruct.new(code: "meal", effect: :increase, manual?: false),
      OpenStruct.new(code: "late", effect: :increase, manual?: false),
      OpenStruct.new(code: "dues", effect: :increase, manual?: true),
      OpenStruct.new(code: "othchg", effect: :increase, manual?: true),
      OpenStruct.new(code: "payment", effect: :decrease, manual?: true),
      OpenStruct.new(code: "reimb", effect: :decrease, manual?: true),
      OpenStruct.new(code: "initcrd", effect: :decrease, manual?: false),
      OpenStruct.new(code: "othcrd", effect: :decrease, manual?: true)
    ].freeze
    TYPES_BY_CODE = TYPES.index_by(&:code)
    MANUALLY_ADDABLE_TYPES = TYPES.select(&:manual?)

    included do
      scope :credit, -> { where("amount < 0") }
      scope :charge, -> { where("amount > 0") }

      validates :code, presence: true
      validates :description, presence: true
      validates :value, presence: true, numericality: {greater_than: 0}
    end

    def increaser?
      effect == :increase
    end

    # Amount is a signed value reflecting the effect on the balance of the associated account.
    # We don't store the sign in the database because it's confusing to users to have to enter a
    # negative value for a payment. Also, in a double entry accounting system it's not quite that simple.
    # Here, we are imposing the idea that all transactions have positive values and we determine
    # the effect on the account by consulting the transaction type.
    def amount
      increaser? ? value : -value
    end

    def type
      TYPES_BY_CODE[code]
    end
  end
end
