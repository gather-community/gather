# frozen_string_literal: true

module MealsHelper
  def meal_url(meal, *args)
    url_in_community(meal.community, meal_path(meal, *args))
  end

  def meal_date_time(meal, with_break: false)
    date_fmt = params[:time] == "all" ? :short_date_with_yr : :short_date
    spacer = with_break ? tag(:br) : " "
    content_tag(:span, l(meal.served_at, format: date_fmt), class: "date") <<
      spacer << content_tag(:span, l(meal.served_at, format: :time_only), class: "time")
  end

  def signup_link(meal)
    link_to(current_user.credit_exceeded?(meal.community) ? icon_tag("ban") : "Sign Up",
      meal_url(meal, signup: 1, anchor: "signup"))
  end

  def signup_count(meal)
    icon = meal.full? ? "exclamation-circle" : "users"
    "#{icon_tag(icon)} #{meal.signup_count}/#{meal.capacity}".html_safe
  end

  def signup_label(type)
    icon_tag("question-circle", title: t("signups.tooltips.#{type}"), data: {toggle: "tooltip"}) <<
      t("signups.diner_types.#{type}", count: 1)
  end
end
