module Billing
  class StatementDecorator < ApplicationDecorator
    delegate_all

    def household_name
      account.decorate.household_name
    end
  end
end
