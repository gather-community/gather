# frozen_string_literal: true

module Meals
  # Makes textual summaries of each section of a form. Meal can be assumed to be persisted.
  class FormSectionSummarizer < ApplicationDecorator
    attr_accessor :meal

    def initialize(meal)
      self.meal = meal
    end

    def summary(section)
      send("#{section}_summary")
    end

    private

    def general_summary
      str = safe_str << "#{meal.served_at_datetime}, #{meal.location_name}, #{meal.formula_name}, "
      allow_key = h.multi_community? ? "allows_with_cmtys" : "allows"
      allow_key = "meals.form.summaries.#{allow_key}"
      str << t(allow_key, people: meal.capacity, count: meal.communities.size)
    end

    def workers_summary
      if meal.workers.empty?
        safe_str << t("meals.form.summaries.no_workers")
      else
        h.safe_join(UserDecorator.decorate_collection(meal.workers).map(&:name), ", ")
      end
    end

    def menu_summary
      if meal.menu_posted?
        items = Meal::MENU_ITEMS.select { |i| meal[i].present? }
        items = items.map { |i| Meal.human_attribute_name(i).downcase }.join(", ")
        items = items.empty? ? nil : t("meals.form.summaries.with_items", items: items)
        allergens = t("meals.form.summaries.and_allergen_count", count: meal.allergens.without("none").size)
        h.safe_join([meal.title, items, allergens].compact, (", "))
      else
        safe_str << t("meals.form.summaries.no_menu")
      end
    end
  end
end
