# frozen_string_literal: true

module Billing
  module TransactionEditable
    extend ActiveSupport::Concern

    included do
      helper_method :transaction_code_options
    end

    def transaction_code_options
      Transaction::MANUALLY_ADDABLE_TYPES.map { |t| [I18n.t("transaction_codes.#{t.code}"), t.code] }
    end
  end
end
