# frozen_string_literal: true

module Meals
  # Models a single section of the meal form.
  class FormSection < ApplicationDecorator
    def initialize(meal, section, expanded:, &block)
      self.meal = meal
      self.section = section
      self.expanded = true # Trying this without collapsing for now.
      self.block = block
    end

    def html
      h.tag.section(id: section) { header << summary << fields }
    end

    private

    attr_accessor :meal, :section, :expanded, :block
    alias expanded? expanded

    def header
      h.tag.h2(t("meals.form.sections.label.#{section}"), class: ("top" if section == :general))
    end

    def summary
      return nil unless collapse?

      text = send("#{section}_summary")
      link = h.link_to(t("meals.form.sections.edit.#{section}"), "#", "data-toggle": section)
      h.tag.p(text << nbsp(2) << link, class: "summary", "data-toggle-on": section)
    end

    def fields
      attribs = {class: "fields", "data-toggle-off": collapse? ? section : nil}
      h.tag.div(block_content, attribs)
    end

    def collapse?
      !expanded? && meal.persisted? && !block_content.match?(/class="error("| )/)
    end

    def block_content
      @block_content ||= h.capture(&block)
    end

    def general_summary
      str = safe_str << "#{meal.served_at_datetime}, #{meal.location_name}, #{meal.formula_name}, "
      allow_key = h.multi_community? ? "allows_with_cmtys" : "allows"
      allow_key = "meals.form.summaries.#{allow_key}"
      str << t(allow_key, people: meal.capacity, count: meal.communities.size)
    end

    def workers_summary
      nonblank_workers = meal.workers.reject(&:blank?)
      if nonblank_workers.empty?
        safe_str << t("meals.form.summaries.no_workers")
      else
        h.safe_join(UserDecorator.decorate_collection(nonblank_workers).map(&:name), ", ")
      end
    end

    def menu_summary
      if meal.menu_posted?
        items = Meal::MENU_ITEMS.select { |i| meal[i].present? }
        items = items.map { |i| Meal.human_attribute_name(i).downcase }.join(", ")
        items = items.empty? ? nil : t("meals.form.summaries.with_items", items: items)
        allergens = t("meals.form.summaries.and_allergen_count", count: meal.allergens.size)
        h.safe_join([meal.title, items, allergens].compact, ", ")
      else
        safe_str << t("meals.form.summaries.no_menu")
      end
    end

    def expenses_summary
      cost = meal.cost
      base_key = "meals.form.summaries.expenses"
      return safe_str << t("#{base_key}.none") if cost.blank?

      chunks = []
      chunks << t("#{base_key}.ingredients", cost: cost.ingredient_cost_formatted)
      chunks << t("#{base_key}.pantry", cost: cost.pantry_cost_formatted) if cost.pantry_cost.present?
      if cost.payment_method.present?
        chunks << t("#{base_key}.payment", method: cost.payment_method_formatted).downcase
      end
      h.safe_join(chunks, ", ")
    end

    def signups_summary
      if meal.signups.any?
        safe_str << t("meals.form.summaries.signups.diners", count: meal.signup_count) << " " <<
          t("meals.form.summaries.signups.from_households", count: meal.signups.size)
      else
        safe_str << t("meals.form.summaries.no_signups")
      end
    end
  end
end
