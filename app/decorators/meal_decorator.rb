class MealDecorator < ApplicationDecorator
  delegate_all

  def css_classes
    if cancelled?
      "cancelled"
    elsif signup_for(h.current_user.household).present?
      "signed-up"
    else
      ""
    end
  end

  def location_name
    resources.first.decorate.name_with_prefix
  end

  def location_abbrv
    resources.first.decorate.abbrv_with_prefix
  end

  def served_at_datetime
    I18n.l(served_at, format: :full_datetime).gsub("  ", " ")
  end

  def served_at_datetime_no_yr
    I18n.l(served_at, format: :datetime_no_yr).gsub("  ", " ")
  end

  def served_at_short_date
    I18n.l(served_at, format: :short_date).gsub("  ", " ")
  end

  def served_at_shorter_date
    I18n.l(served_at, format: :shorter_date).gsub("  ", " ")
  end
end
