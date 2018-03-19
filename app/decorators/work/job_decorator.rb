# frozen_string_literal: true

module Work
  class JobDecorator < WorkDecorator
    delegate_all

    delegate :name, to: :requester, prefix: true, allow_nil: true

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_work_job_path(object))
      )
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.work_job_path(object),
                                         method: :delete, confirm: {title: title})
      )
    end

    def link_with_icon
      h.link_to(title, h.policy(object).edit? ? h.edit_work_job_path(object) : h.work_job_path(object)) <<
        " " << slot_type_icon
    end

    def title_with_icon
      str = "".html_safe << title
      str << " " << full_community_icon if full_community?
      str
    end

    def slot_type_icon
      full_group? ? h.icon_tag("users") : ""
    end

    def hours_formatted
      to_int_if_no_fractional_part(hours)
    end

    def total_slots_formatted
      total_slots >= Shift::UNLIMITED_SLOTS ? h.t("common.unlimited") : total_slots
    end
  end
end
