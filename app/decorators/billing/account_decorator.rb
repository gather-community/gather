module Billing
  class AccountDecorator < ApplicationDecorator
    delegate_all

    def household_name
      household.decorate.name
    end
  end
end
