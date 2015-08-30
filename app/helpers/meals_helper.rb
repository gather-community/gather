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

  def meal_action_icons(meal, options = {})
    options[:except] = Array.wrap(options[:except] || [])
    to_show = [:edit, :destroy] - options[:except]

    links = []
    title = meal.title || "Untitled"
    to_show.each do |action|
      next if cannot?(action, meal)
      name = options[:show_name] ? " " << t("action_names.#{action}") : ""

      case action
      when :edit
        links << link_to(icon_tag('pencil') << name, edit_meal_path(meal))
      when :destroy
        links << link_to(icon_tag('trash') << name, meal_path(meal), method: :delete,
          data: { confirm: I18n.t("activerecord.delete_confirms.meal", title: title) })
      end
    end

    content_tag(:div, links.reduce(:<<), class: "action-icons")
  end

  def signup_link(meal)
    current_user.over_limit?(meal.host_community) ? "" : link_to("Sign Up", meal_path(meal))
  end

  def signup_count(meal)
    icon = meal.full? ? "exclamation-circle" : "users"
    "#{icon_tag(icon)} #{meal.signup_count}/#{meal.capacity}".html_safe
  end

  def signup_label(type)
    icon_tag("question-circle", title: t("signups.tooltips.#{type}"), data: {toggle: "tooltip"}) <<
      Signup.human_attribute_name(type)
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
