module MealsHelper
  def signed_up_class(meal)
    meal.signup_for(current_user).present? ? "signed-up" : ""
  end

  def meal_date_time(meal)
    content_tag(:span, meal.served_at.to_formatted_s(:short_date), class: "date") <<
      " ".html_safe << content_tag(:span, meal.served_at.to_formatted_s(:regular_time), class: "time")
  end
end
