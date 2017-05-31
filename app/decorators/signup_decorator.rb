class SignupDecorator < ApplicationDecorator
  delegate_all

  def household_name
    household.decorate.name
  end
end
