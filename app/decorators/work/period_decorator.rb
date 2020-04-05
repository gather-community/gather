# frozen_string_literal: true

module Work
  class PeriodDecorator < ApplicationDecorator
    delegate_all

    def round_duration_options
      (1..15).to_a.map { |i| [t("work/period.num_minutes", count: i), i] }
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :review_notices, icon: "bullhorn",
                                                path: h.review_notices_work_period_path(object)),
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_work_period_path(object))
      )
    end

    def notices_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :send_notices, icon: "send", method: :post, btn_class: :primary,
                                              path: h.send_notices_work_period_path(object))
      )
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.work_period_path(object),
                                         method: :delete, confirm: {name: name})
      )
    end
  end
end
