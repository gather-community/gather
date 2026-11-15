# frozen_string_literal: true

module Meals
  class ReportDecorator < ApplicationDecorator
    delegate_all

    def range_formatted
      %w[first last].map { |m| l(range.send(m), format: :full_month_year) }.join(" - ")
    end

    def subhead(current_cmty_only: true)
      text = if h.multi_community? && current_cmty_only
        h.t("meals.report.subhead_community", range: range_formatted, community: community.name)
      else
        range_formatted
      end
      h.content_tag(:small, text)
    end
  end
end
