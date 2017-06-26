class MealDecorator < ApplicationDecorator
  delegate_all

  def location_name
    resources.first.decorate.name
  end

  def location_abbrv
    resources.first.decorate.meal_abbrv
  end

  def served_at_datetime_no_yr
    I18n.l(served_at, format: :datetime_no_yr).gsub("  ", " ")
  end

  def served_at_short_date
    I18n.l(served_at, format: :short_date).gsub("  ", " ")
  end
end
