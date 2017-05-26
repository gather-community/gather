module Billing
  class TransactionDecorator < Draper::Decorator
    delegate_all

    def household_name
      account.decorate.household_name
    end
  end
end
