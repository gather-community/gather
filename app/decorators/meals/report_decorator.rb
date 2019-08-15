# frozen_string_literal: true

module Meals
  class ReportDecorator < ApplicationDecorator
    delegate_all

    def range_formatted
      %w[first last].map { |m| l(range.send(m), format: :month_yr) }.join(" - ")
    end

    def this_cmty_only
      multi_community? ? ", #{community.name} meals only" : ""
    end
  end
end
