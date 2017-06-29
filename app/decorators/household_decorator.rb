class HouseholdDecorator < ApplicationDecorator
  delegate_all

  def name_with_prefix
    suffix = "#{active? ? '' : ' (Inactive)'}"
    "#{cmty_prefix}#{object.name}#{suffix}"
  end
end
