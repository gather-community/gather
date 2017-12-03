module MealsHelper
  def meal_link(meal)
    link_to(meal.title_or_no_title, meal_url(meal))
  end

  def meal_url(meal)
    url_in_community(meal.community, meal_path(meal))
  end

  def meal_date_time(meal, with_break: false)
    date_fmt = params[:time] == "all" ? :short_date_with_yr : :short_date
    spacer = with_break ? tag(:br) : " "
    content_tag(:span, meal.served_at.to_formatted_s(date_fmt), class: "date") <<
      spacer << content_tag(:span, meal.served_at.to_formatted_s(:regular_time), class: "time")
  end

  def signup_info(signup)
    icon_tag("check") << " #{signup.total}"
  end

  def signup_link(meal)
    link_to(current_user.credit_exceeded?(meal.community) ? icon_tag("ban") : "Sign Up", meal_url(meal))
  end

  def signup_count(meal)
    icon = meal.full? ? "exclamation-circle" : "users"
    "#{icon_tag(icon)} #{meal.signup_count}/#{meal.capacity}".html_safe
  end

  def signup_label(type)
    icon_tag("question-circle", title: t("signups.tooltips.#{type}"), data: {toggle: "tooltip"}) <<
      t("signups.diner_types.#{type}", count: 1)
  end

  def community_invited?(meal, community)
    meal.community_ids.include?(community.id)
  end

  # We should disable the "own" community checkbox for most users.
  def disable_community_checkbox?(meal, community)
    disable = meal.community == community && community_invited?(meal, community)
    disable ? "disabled" : nil
  end

  def sorted_allergens
    prefix = "activerecord.attributes.meal.allergen_"
    Meal::ALLERGENS.sort_by { |a| [a == "none" ? 1 : 0, I18n.t("#{prefix}_#{a}")] }
  end
end
