# frozen_string_literal: true

module Meals
  class PortionCountBuilder < ApplicationDecorator
    delegate_all

    def portion_counts
      nil_category_formula_parts = formula_parts_by_category.delete(nil)
      chunks = formula_parts_by_category.map { |c, fp| chunk(c, fp) }
      chunks << chunk(nil, nil_category_formula_parts, only: chunks.empty?) if nil_category_formula_parts
      ttl_signups = h.tag.strong("#{signup_count} diners")
      h.tag.div(class: "portion-counts") do
        if chunks.size == 1
          safe_str << "This meal has " << ttl_signups << " and will require approximately " <<
            chunks[0] << ".*"
        else
          safe_str << "This meal has " << ttl_signups << " and will require approximately: " <<
            chunks.reduce(&sep(", ")) << ".*"
        end
      end
    end

    private

    def chunk(category, formula_parts, only: false)
      formula_parts_by_type = formula_parts.index_by(&:type)
      h.tag.strong do
        total = signups.sum do |signup|
          signup.parts.sum do |signup_part|
            matching_formula_part = formula_parts_by_type[signup_part.type]
            matching_formula_part ? signup_part.count.to_f * matching_formula_part.portion_size : 0
          end
        end
        category = "other" if category.nil? && !only
        [total.ceil, category].compact.join(" ")
      end << " portions"
    end

    def formula_parts_by_category
      @formula_parts_by_category ||= formula.parts.includes(:type).group_by(&:category)
    end
  end
end
