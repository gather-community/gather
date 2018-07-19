# frozen_string_literal: true

module Meals
  # Makes textual summaries of each section of a form. Meal can be assumed to be persisted.
  class FormSectionSummarizer < ApplicationDecorator
    attr_accessor :meal

    def initialize(meal)
      self.meal = meal
    end

    def general_summary
      str = +"#{meal.served_at_datetime}, #{meal.location_name}, #{meal.formula_name}, "
      allow_key = h.multi_community? ? "allows_with_cmtys" : "allows"
      allow_key = "meal_form_summarizer.#{allow_key}"
      str << t(allow_key, people: meal.capacity, count: meal.communities.size)
    end

    def workers_summary
      if meal.workers.empty?
        t("meal_form_summarizer.no_workers")
      else
        UserDecorator.decorate_collection(meal.workers).map(&:name).join(", ")
      end
    end

    def menu_summary
      if meal.menu_posted?
        items = Meal::MENU_ITEMS.select { |i| meal[i].present? }
        items = items.map { |i| Meal.human_attribute_name(i).downcase }.join(", ")
        items = items.empty? ? nil : t("meal_form_summarizer.with_items", items: items)
        allergens = t("meal_form_summarizer.and_allergen_count", count: meal.allergens.without("none").size)
        [meal.title, items, allergens].compact.join(", ")
      else
        t("meal_form_summarizer.no_menu")
      end
    end
  end
end
