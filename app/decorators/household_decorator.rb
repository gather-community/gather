class HouseholdDecorator < ApplicationDecorator
  delegate_all

  def name
    suffix = "#{active? ? '' : ' (Inactive)'}"
    "#{cmty_prefix}#{object.name}#{suffix}"
  end
end
