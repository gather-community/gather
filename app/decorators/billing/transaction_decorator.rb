module Billing
  class TransactionDecorator < ApplicationDecorator
    delegate_all

    def household_name
      account.decorate.household_name
    end
  end
end
