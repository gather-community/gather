# frozen_string_literal: true

module Work
  class JobDecorator < ApplicationDecorator
    delegate_all

    delegate :name, to: :requester, prefix: true, allow_nil: true

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.work_job_path(object),
                                         method: :delete, confirm: {title: title})
      )
    end

    def slot_type_icon
      full_group? ? h.icon_tag("users") : ""
    end

    def hours_formatted
      to_int_if_no_fractional_part(hours)
    end

    def slot_count_formatted
      slot_count >= Shift::UNLIMITED_SLOT_COUNT ? h.t("common.unlimited") : slot_count
    end
  end
end
