# frozen_string_literal: true

module Concerns::ApplicationController::Csv
  extend ActiveSupport::Concern

  def csv_filename(*parts)
    parts.map do |p|
      if p == :community
        current_community.slug
      elsif p == :date
        Time.current.to_s(:iso8601_date)
      else
        p
      end
    end.join("-") << ".csv"
  end
end
