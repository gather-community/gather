# frozen_string_literal: true

class SignupDecorator < ApplicationDecorator
  delegate_all

  def household_name
    household.nil? ? "" : household.decorate.name_with_prefix
  end

  def count_or_blank(type)
    if (count = object[type]) && count.positive?
      count
    else
      ""
    end
  end

  # Returns the household name or, if not persisted, a select2 control for selecting it.
  # Used as the label in the signup form.
  def household_as_label(form)
    if persisted?
      household.decorate.name_with_prefix
    else
      form.error(:household_id)
      form.select(:household_id, household&.decorate&.selected_option || "", {},
        class: "form-control", data: {"select2-src" => "households",
                                      "select2-label-attr" => "name_with_prefix",
                                      "select2-prompt" => t("select2.prompts.household"),
                                      "select2-placeholder" => t("select2.placeholders.household"),
                                      "select2-context" => "meal_form",
                                      "select2-allow-clear" => true})
    end
  end
end
