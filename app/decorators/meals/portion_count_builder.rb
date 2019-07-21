# frozen_string_literal: true

module Meals
  class PortionCountBuilder < ApplicationDecorator
    delegate_all

    def portion_counts
      chunks = formula_parts_by_category.map { |c, fp| chunk(c, fp) }
      safe_str << "This meal will require approximately " << chunks.reduce(&sep(" and ")) << ".*"
    end

    private

    def chunk(category, formula_parts)
      formula_parts_by_type = formula_parts.index_by(&:type)
      h.content_tag(:strong) do
        total = signups.sum do |signup|
          signup.parts.sum do |signup_part|
            matching_formula_part = formula_parts_by_type[signup_part.type]
            matching_formula_part ? signup_part.count * matching_formula_part.share : 0
          end
        end
        "#{total.ceil} #{category}"
      end << " portions"
    end

    def formula_parts_by_category
      @formula_parts_by_category ||= formula.parts.group_by(&:category)
    end
  end
end
