# frozen_string_literal: true

module Calendars
  class GroupDecorator < ApplicationDecorator
    delegate_all

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", method: :delete, confirm: {name: name},
                                         path: h.calendars_group_path(object))
      )
    end
  end
end
