# frozen_string_literal: true

module Billing
  class AccountDecorator < ApplicationDecorator
    delegate_all

    def household_name
      household.decorate.name_with_prefix
    end

    def pos_cur_bal_and_credit_limit?
      positive_current_balance? && credit_limit?
    end

    def credit_limit_or_none
      if credit_limit?
        num = h.number_to_currency(credit_limit)
        credit_exceeded? ? content_tag(:span, num, class: "exceeded") : num
      else
        "None"
      end
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_account_path(object)),
        ActionLink.new(object, :add_txn, icon: "plus", path: h.new_account_transaction_path(object))
      )
    end
  end
end
