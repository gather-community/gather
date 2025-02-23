# frozen_string_literal: true

module Meals
  class SignupDecorator < ApplicationDecorator
    delegate_all

    def household_name
      household.nil? ? "" : household.decorate.name_with_prefix
    end

    def count_or_blank(type)
      count = parts_by_type[type]&.count
      count.nil? || count.zero? ? "" : count
    end

    def total_diners_formatted
      h.icon_tag("check") << " #{total}"
    end

    def takeout_cell
      return "" unless takeout?

      safe_str << "✔" << nbsp << "Takeout"
    end

    # Returns the household name or, if not persisted, a select2 control for selecting it.
    # Used as the label in the signup form.
    def household_as_label(form)
      if persisted?
        form.hidden_field(:household_id) << household.decorate.name_with_prefix

      else
        form.select(:household_id, household&.decorate&.selected_option_tag || "", {},
                    {class: "form-control", data: {"select2-src" => h.households_path,
                                                   "select2-label-attr" => "nameWithPrefix",
                                                   "select2-prompt" => t("select2.prompts.household"),
                                                   "select2-placeholder" => t("select2.placeholders.household"),
                                                   "select2-context" => "meal_form",
                                                   "select2-allow-clear" => true}}) <<
          (form.error(:household_id) || "")
      end
    end
  end
end
