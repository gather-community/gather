# frozen_string_literal: true

module Billing
  module TransactableDecorable
    extend ActiveSupport::Concern

    # Radio button options for the manually addable types with the given effect (:increase or :decrease),
    # as [label, code] pairs.
    def transaction_code_options(effect)
      Transaction::MANUALLY_ADDABLE_TYPES.select { |type| type.effect == effect }.map do |type|
        [h.t("simple_form.options.billing_transaction.code.#{type.code}"), type.code]
      end
    end
  end
end
