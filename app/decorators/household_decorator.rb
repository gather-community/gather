class HouseholdDecorator < ApplicationDecorator
  delegate_all

  def greeting
    I18n.t("households.greeting", name: name)
  end

  def name_with_prefix
    suffix = "#{active? ? '' : ' (Inactive)'}"
    "#{cmty_prefix}#{object.name}#{suffix}"
  end

  def selected_option
    h.content_tag(:option, name_with_prefix, value: id, selected: "selected")
  end
end
