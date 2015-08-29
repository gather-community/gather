module MealsHelper
  def meal_link(meal)
    link_to(meal.title || "[No Title]", meal_path(meal))
  end

  def signed_up_class(meal)
    meal.signup_for(current_user.household).present? ? "signed-up" : ""
  end

  def meal_date_time(meal)
    content_tag(:span, meal.served_at.to_formatted_s(:short_date), class: "date") <<
      " ".html_safe << content_tag(:span, meal.served_at.to_formatted_s(:regular_time), class: "time")
  end

  def meal_action_icons(meal)
    (can?(:edit, meal) ? link_to(icon_tag('pencil'), edit_meal_path(meal)) : "") << " ".html_safe #<<
      #(can?(:destroy, meal) ? link_to(icon_tag('trash'), meal_path(meal), method: :delete) : "")
  end

  def signup_count(meal)
    icon = meal.full? ? "exclamation-circle" : "users"
    "#{icon_tag(icon)} #{meal.signup_count}/#{meal.capacity}".html_safe
  end

  def community_invited?(meal, community)
    meal.community_ids.include?(community.id)
  end

  # We should disable the "own" community checkbox for most users.
  def disable_community_checkbox?(meal, community)
    disable = current_user.community == community &&
      community_invited?(meal, community) &&
      current_ability.cannot?(:manage_other_community, meal)
    disable ? "disabled" : nil
  end
end
