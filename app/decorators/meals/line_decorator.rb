# frozen_string_literal: true

module Meals
  class LineDecorator < ApplicationDecorator
    delegate_all

    def to_s
      item = I18n.t("signups.types.#{item_id}")
      "#{quantity} #{item}"
    end
  end
end
