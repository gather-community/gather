# frozen_string_literal: true

module Calendars
  class CalendarDecorator < ApplicationDecorator
    delegate_all

    # Form helper guesses this wrong b/c it's not namespaced.
    def submission_url
      new_record? ? h.calendars_path : h.calendar_path(object)
    end

    def name_with_prefix
      "#{cmty_prefix_no_colon}#{name}"
    end

    def name_with_inactive
      "#{name}#{active? ? '' : ' (Inactive)'}"
    end

    def abbrv_with_prefix
      "#{cmty_prefix_no_colon}#{abbrv}"
    end

    def tr_classes
      active? ? "" : "inactive"
    end

    def swatch(color, least_used_colors)
      least_used = least_used_colors.include?(color)
      fg_color_style = least_used ? "; color: #{color}" : ""
      h.content_tag(:div, "×", class: "swatch", style: "background-color: #{color}#{fg_color_style}",
                               data: {color: color})
    end

    def photo_variant(format)
      return "missing/calendars/calendars/#{format}.png" unless photo.attached? && photo.variable?
      case format
      when :thumb then photo.variant(resize_to_fill: [220, 165])
      else raise "Unknown photo format #{format}"
      end
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :deactivate, icon: "times-circle", method: :put, confirm: {name: name},
                                            path: h.deactivate_calendar_path(object)),
        ActionLink.new(object, :destroy, icon: "trash", method: :delete, confirm: {name: name},
                                         path: h.calendar_path(object))
      )
    end
  end
end
