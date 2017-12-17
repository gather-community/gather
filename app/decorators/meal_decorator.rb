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

  def show_action_link_set
    ActionLinkSet.new(
      ActionLink.new(object, :edit, icon: "pencil", path: h.edit_meal_path(object)),
      ActionLink.new(object, :summary, icon: "file-text", path: h.summary_meal_path(object)),
      ActionLink.new(object, :reopen, icon: "unlock", path: h.reopen_meal_path(object), method: :put),
      ActionLink.new(object, :close, icon: "lock", path: h.close_meal_path(object), method: :put),
      ActionLink.new(object, :finalize, icon: "certificate", path: h.new_meal_finalize_path(object)),
      ActionLink.new(object, :cancel, icon: "ban", path: h.new_meal_message_path(object, cancel: 1)),
      ActionLink.new(object, :send_message, icon: "envelope", path: h.new_meal_message_path(object)),
    )
  end

  def edit_action_link_set
    ActionLinkSet.new(
      ActionLink.new(object, :destroy, icon: "trash", path: h.meal_path(object), method: :delete,
        confirm: {title: object.title_or_no_title})
    )
  end
end
