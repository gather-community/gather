module Work
  class PeriodDecorator < ApplicationDecorator
    delegate_all

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.work_period_path(object),
          method: :delete, confirm: {name: name})
      )
    end
  end
end
