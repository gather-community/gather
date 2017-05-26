module Billing
  class AccountDecorator < Draper::Decorator
    delegate_all

    def household_name
      household.decorate.name
    end
  end
end
