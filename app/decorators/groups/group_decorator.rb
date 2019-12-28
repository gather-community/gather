# frozen_string_literal: true

module Groups
  class GroupDecorator < ApplicationDecorator
    delegate_all

    def name_with_suffix
      suffixes = []
      suffixes << t("common.inactive") if inactive?
      suffixes << t("common.hidden") if hidden?
      suffixes = suffixes.empty? ? "" : " (#{suffixes.join(', ')})"
      "#{name}#{suffixes}"
    end

    def name_with_inactive
      "#{name}#{active? ? '' : ' (Inactive)'}"
    end

    def tr_classes
      [active? ? nil : "inactive", hidden? ? "muted" : nil].compact.join(" ")
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :deactivate, icon: "times-circle", method: :put, confirm: {name: name},
                                            path: h.deactivate_group_path(object)),
        ActionLink.new(object, :destroy, icon: "trash", method: :delete, confirm: {name: name},
                                         path: h.group_path(object))
      )
    end
  end
end
