# frozen_string_literal: true

module People
  class MemberTypeDecorator < ApplicationDecorator
    delegate_all

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_people_member_type_path(object))
      )
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.people_member_type_path(object),
                                         method: :delete, confirm: {name: name})
      )
    end
  end
end
