# frozen_string_literal: true

module Meals
  # Models a single section of the meal form.
  class FormSection < ApplicationDecorator
    def initialize(meal, section, &block)
      self.meal = meal
      self.section = section
      self.block = block
    end

    def html
      h.content_tag(:section, id: section) { header << summary << fields }
    end

    private

    attr_accessor :meal, :section, :block

    def header
      h.content_tag(:h2, t("meals.form.sections.label.#{section}"), class: ("top" if section == :general))
    end

    def summary
      return nil unless collapse?
      text = send("#{section}_summary")
      link = h.link_to(t("meals.form.sections.edit.#{section}"), "#", "data-toggle": section)
      h.content_tag(:p, text << nbsp(2) << link, class: "summary", "data-toggle-on": section)
    end

    def fields
      attribs = {class: "fields", "data-toggle-off": collapse? ? section : nil}
      h.content_tag(:div, block_content, attribs)
    end

    def collapse?
      meal.persisted? && !block_content.match?(/\bhas-error\b/)
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
        h.safe_join([meal.title, items, allergens].compact, ", ")
      else
        safe_str << t("meals.form.summaries.no_menu")
      end
    end
  end
end
