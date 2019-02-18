module Work
  class PeriodDecorator < ApplicationDecorator
    delegate_all

    def round_duration_options
      (1..15).to_a.map { |i| [t("work/period.num_minutes", count: i), i] }
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.work_period_path(object),
          method: :delete, confirm: {name: name})
      )
    end
  end
end
