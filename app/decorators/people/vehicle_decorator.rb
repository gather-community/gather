# frozen_string_literal: true

module People
  class VehicleDecorator < ApplicationDecorator
    delegate_all

    def make_model_etc
      "#{make} #{model}, #{color}#{plate_or_blank}"
    end

    private

    def plate_or_blank
      plate.present? ? " (#{plate})" : ""
    end

    # The `model` method orginarily returns `self`.
    def model
      object[:model]
    end
  end
end
