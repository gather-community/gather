# frozen_string_literal: true

module Billing
  module TransactableDecorable
    extend ActiveSupport::Concern

    def transaction_code_options
      Transaction::MANUALLY_ADDABLE_TYPES.map do |type|
        icon = type.effect == :increase ? h.icon_tag("arrow-up") : h.icon_tag("arrow-down")
        [safe_str << I18n.t("transaction_codes.#{type.code}") << nbsp << nbsp << icon, type.code]
      end
    end
  end
end
