module Billing
  class StatementDecorator < ApplicationDecorator
    delegate_all

    delegate :name, to: :community, prefix: true

    def household_name
      account.decorate.household_name
    end
  end
end
