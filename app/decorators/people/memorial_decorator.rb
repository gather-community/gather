# frozen_string_literal: true

module People
  class MemorialDecorator < ApplicationDecorator
    delegate_all

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_people_memorial_path(object))
      )
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.people_memorial_path(object),
          method: :delete, confirm: {name: name})
      )
    end

    # Mirrors UserDecorator#photo_variant, but reads the memorial's own copy of the photo so it
    # still renders once the account has been deleted.
    def photo_variant(format)
      return "missing/users/#{format}.png" if !photo.attached? || !photo.variable?
      case format
      when :thumb then photo.variant(resize_to_fill: [150, 150])
      when :medium then photo.variant(resize_to_fill: [300, 300])
      else raise "Unknown photo format #{format}"
      end
    end
  end
end
