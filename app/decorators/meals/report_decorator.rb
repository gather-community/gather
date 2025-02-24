# frozen_string_literal: true

module Meals
  class ReportDecorator < ApplicationDecorator
    delegate_all

    def range_formatted
      %w[first last].map { |m| l(range.send(m), format: :full_month_year) }.join(" - ")
    end

    def subhead(current_cmty_only: true)
      cmty_str = h.multi_community? && current_cmty_only ? ", #{community.name} meals only" : ""
      h.tag.small(range_formatted << cmty_str)
    end
  end
end
