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

    # Build list of icons to show
    to_show = [].tap do |a|
      a << :edit
      a << :summary
      a << :reopen if meal.reopenable?
      a << :close if meal.closeable?
      a << :destroy
      options[:except].each{ |x| a.delete(x) }
    end

    links = []
    title = meal.title || "Untitled"
    to_show.each do |action|
      next if cannot?(action, meal)
      name = options[:show_name] ? " " << t("action_names.#{action}") : ""

      case action
      when :edit
        links << link_to(icon_tag('pencil') << name, edit_meal_path(meal))
      when :summary
        links << link_to(icon_tag('print') << name, summary_meal_path(meal))
      when :close
        links << link_to(icon_tag('lock') << name, close_meal_path(meal), method: :put)
      when :reopen
        links << link_to(icon_tag('unlock') << name, reopen_meal_path(meal), method: :put)
      when :destroy
        links << link_to(icon_tag('trash') << name, meal_path(meal), method: :delete,
          data: { confirm: I18n.t("activerecord.delete_confirms.meal", title: title) })
      end
    end

    cls = options[:show_name] ? "action-icons-with-names" : ""
    content_tag(:div, links.reduce(:<<), class: "action-icons #{cls}")
  end

  def signup_info(signup)
    icon_tag("check") << " #{signup.total}"
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
      t("signups.diner_types.#{type}", count: 1)
  end

  def community_invited?(meal, community)
    meal.community_ids.include?(community.id)
  end

  # We should disable the "own" community checkbox for most users.
  def disable_community_checkbox?(meal, community)
    disable = meal.host_community == community &&
      community_invited?(meal, community) &&
      current_ability.cannot?(:manage_other_community, meal)
    disable ? "disabled" : nil
  end

  def clear_work_filter_link(text)
    link_to(text, "#", onclick: "$('#uid').val(''); $('.index-filter').submit(); return false;")
  end

  def portion_counts(meal)
    "This meal will require approximately ".html_safe <<
      Signup::FOOD_TYPES.map do |ft|
        content_tag(:strong) do
          num = meal.portions(ft).ceil
          ft_str = t("signups.food_types.#{ft}").downcase
          "#{num} #{ft_str}"
        end << " portions"
      end.reduce(&sep(" and ")) << ".*"
  end
end
