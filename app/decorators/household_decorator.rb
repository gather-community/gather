class HouseholdDecorator < ApplicationDecorator
  delegate_all

  def name
    prefix = h.multi_community? ? "#{community.abbrv}: " : ""
    suffix = "#{active? ? '' : ' (Inactive)'}"
    "#{prefix}#{object.name}#{suffix}"
  end
end
