# frozen_string_literal: true

class MealDecorator < ApplicationDecorator
  delegate_all

  def form_section(section, &block)
    header = h.content_tag(:h2, t("meals.form.sections.label.#{section}"),
      class: ("top" if section == :general))
    summary = form_section_summary(section)
    fields = h.content_tag(:div, class: "fields", "data-toggle-off": persisted? ? section : nil) do
      h.capture(&block)
    end
    h.content_tag(:section, id: section) do
      header << summary << fields
    end
  end

  def form_section_summary(section)
    return nil if new_record?
    text = form_section_summarizer.summary(section)
    link = h.link_to(t("meals.form.sections.edit.#{section}"), "#", "data-toggle": section)
    h.content_tag(:p, text << nbsp(2) << link, class: "summary", "data-toggle-on": section)
  end

  def css_classes
    if cancelled?
      "cancelled"
    elsif signup_for(h.current_user.household).present?
      "signed-up"
    else
      ""
    end
  end

  # Returns a non-persisted SignupPolicy with this meal. Used for policy checks.
  def sample_signup
    @sample_signup ||= Signup.new(meal: meal)
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

  # We should disable the "own" community checkbox for most users.
  def disable_community_checkbox?(community)
    disable = (object.community == community && community_invited?(community))
    disable ? "disabled" : nil
  end

  def show_action_link_set
    ActionLinkSet.new(
      ActionLink.new(object, :edit, icon: "pencil", path: h.edit_meal_path(object)),
      ActionLink.new(object, :summary, icon: "file-text", path: h.summary_meal_path(object)),
      ActionLink.new(object, :reopen, icon: "unlock", path: h.reopen_meal_path(object),
                                      method: :put, confirm: true),
      ActionLink.new(object, :close, icon: "lock", path: h.close_meal_path(object),
                                     method: :put, confirm: true),
      ActionLink.new(object, :finalize, icon: "certificate", path: h.new_meal_finalize_path(object)),
      ActionLink.new(object, :cancel, icon: "ban", path: h.new_meal_message_path(object, cancel: 1)),
      ActionLink.new(object, :send_message, icon: "envelope", path: h.new_meal_message_path(object))
    )
  end

  def edit_action_link_set
    ActionLinkSet.new(
      ActionLink.new(object, :destroy, icon: "trash", path: h.meal_path(object), method: :delete,
                                       confirm: {title: object.title_or_no_title})
    )
  end

  private

  def form_section_summarizer
    @form_section_summarizer ||= Meals::FormSectionSummarizer.new(self)
  end
end
