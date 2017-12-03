module Billing
  class AccountDecorator < ApplicationDecorator
    delegate_all

    def household_name
      household.decorate.name_with_prefix
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_account_path(object)),
        ActionLink.new(object, :add_txn, icon: "plus", path: h.new_account_transaction_path(object))
      )
    end
  end
end
