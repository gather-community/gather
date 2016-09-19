module MealsHelper
  def meal_link(meal)
    link_to(meal.title_or_no_title, meal_path(meal))
  end

  def signed_up_class(meal)
    meal.signup_for(current_user.household).present? ? "signed-up" : ""
  end

  def meal_date_time(meal)
    date_fmt = params[:time] == "all" ? :short_date_with_year : :short_date
    content_tag(:span, meal.served_at.to_formatted_s(date_fmt), class: "date") <<
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
      a << :finalize if meal.finalizable?
      a << :destroy
      options[:except].each{ |x| a.delete(x) }
    end

    links = []
    title = meal.title || "Untitled"
    to_show.each do |action|
      next unless policy(meal).send("#{action}?")
      name = options[:show_name] ? " " << t("action_names.#{action}") : ""
      title = t("action_names.#{action}")

      case action
      when :edit
        links << link_to(icon_tag("pencil") << name, edit_meal_path(meal), title: title)
      when :summary
        links << link_to(icon_tag("file-text") << name, summary_meal_path(meal), title: title)
      when :close
        links << link_to(icon_tag("lock") << name, close_meal_path(meal), title: title, method: :put)
      when :finalize
        links << link_to(icon_tag("certificate") << name, finalize_meal_path(meal), title: title)
      when :reopen
        links << link_to(icon_tag("unlock") << name, reopen_meal_path(meal), title: title, method: :put)
      when :destroy
        links << link_to(icon_tag("trash") << name, meal_path(meal), title: title, method: :delete,
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
    link_to(current_user.credit_exceeded?(meal.host_community) ? icon_tag("ban") : "Sign Up", meal_path(meal))
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
    disable = meal.host_community == community && community_invited?(meal, community)
    disable ? "disabled" : nil
  end

  def payment_method_options
    Meal::PAYMENT_METHODS.map{ |m| [I18n.t("payment_methods.#{m}"), m] }
  end

  def sorted_allergens
    prefix = "activerecord.attributes.meal.allergen_"
    Meal::ALLERGENS.sort_by { |a| [a == "none" ? 1 : 0, I18n.t("#{prefix}_#{a}")] }
  end
end
