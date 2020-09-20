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
        ActionLink.new(object, :destroy, icon: "trash", path: h.people_memorial_path(object), method: :delete,
                                         confirm: {name: user.decorate.full_name})
      )
    end
  end
end
