# frozen_string_literal: true

module MealsHelper
  # Use this helper if the current_community *is or may be* different from the target meal's community.
  def meal_url(meal, *)
    url_in_community(meal.community, meal_path(meal, *))
  end

  def signup_link(meal)
    link_to(current_user.credit_exceeded?(meal.community) ? icon_tag("ban") : "Sign Up",
            meal_url(meal, signup: 1, anchor: "signup"))
  end

  def signup_count(meal)
    icon = meal.full? ? "exclamation-circle" : "users"
    "#{icon_tag(icon)}&nbsp;&nbsp;#{meal.signup_count}/#{meal.capacity}".html_safe
  end

  def signup_label(type)
    icon_tag("question-circle", title: t("signups.tooltips.#{type}"), data: {toggle: "tooltip"}) <<
      t("signups.diner_types.#{type}", count: 1)
  end
end
