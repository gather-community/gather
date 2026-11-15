# frozen_string_literal: true

module Meals
  class PortionCountBuilder < ApplicationDecorator
    delegate_all

    def portion_counts
      nil_category_formula_parts = formula_parts_by_category.delete(nil)
      chunks = formula_parts_by_category.map { |c, fp| chunk(c, fp) }
      chunks << chunk(nil, nil_category_formula_parts, only: chunks.empty?) if nil_category_formula_parts
      diners = h.content_tag(:strong, h.t("meals.portion_counts.diners", count: signup_count))
      h.content_tag(:div, class: "portion-counts") do
        if chunks.size == 1
          h.t("meals.portion_counts.summary_html", diners: diners, portions: chunks[0])
        else
          h.t("meals.portion_counts.summary_list_html", diners: diners, portions: chunks.reduce(&sep(", ")))
        end
      end
    end

    private

    def chunk(category, formula_parts, only: false)
      formula_parts_by_type = formula_parts.index_by(&:type)
      total = signups.sum do |signup|
        signup.parts.sum do |signup_part|
          matching_formula_part = formula_parts_by_type[signup_part.type]
          matching_formula_part ? signup_part.count.to_f * matching_formula_part.portion_size : 0
        end
      end
      category = h.t("meals.portion_counts.other_category") if category.nil? && !only
      if category
        h.t("meals.portion_counts.category_portions_html", count: total.ceil, category: category)
      else
        h.t("meals.portion_counts.portions_html", count: total.ceil)
      end
    end

    def formula_parts_by_category
      @formula_parts_by_category ||= formula.parts.includes(:type).group_by(&:category)
    end
  end
end
