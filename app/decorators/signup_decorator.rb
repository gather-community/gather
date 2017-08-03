class SignupDecorator < ApplicationDecorator
  delegate_all

  def household_name
    household.decorate.name_with_prefix
  end

  def count_or_blank(type)
    if (count = object[type]) && count > 0
      count
    else
      ""
    end
  end
end
