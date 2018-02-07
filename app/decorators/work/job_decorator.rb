module Work
  class JobDecorator < ApplicationDecorator
    delegate_all

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.work_job_path(object),
          method: :delete, confirm: {title: title})
      )
    end
  end
end
