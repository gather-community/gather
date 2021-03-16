# frozen_string_literal: true

module Billing
  class TemplateDecorator < ApplicationDecorator
    include TransactableDecorable

    delegate_all

    def member_type_names
      member_types.map(&:name).join(", ")
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.billing_template_path(object),
                                         confirm: {description: description,
                                                   member_types: member_type_names},
                                         method: :delete)
      )
    end
  end
end
