# frozen_string_literal: true

module Reservations
  class ProtocolDecorator < ApplicationDecorator
    delegate_all

    def defined_rule_names
      Rules::Rule::NAMES
        .reject { |n| self[n].nil? }
        .map { |n| h.t("reservations.rule_names.#{n}") }
        .join(", ")
    end

    def resource_names
      general? ? t("common.all") : resources.map(&:name).join(", ")
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.reservations_protocol_path(object),
                                         method: :delete, confirm: {name: name})
      )
    end
  end
end
