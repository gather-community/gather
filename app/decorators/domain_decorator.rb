# frozen_string_literal: true

class DomainDecorator < ApplicationDecorator
  delegate_all

  def show_action_link_set
    ActionLinkSet.new(
      ActionLink.new(object, :destroy, icon: "trash", path: h.domain_path(object), method: :delete,
                                       confirm: {name: name})
    )
  end
end
