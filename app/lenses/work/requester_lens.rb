# frozen_string_literal: true

module Work
  # For filtering work jobs based on requesting group.
  class RequesterLens < Lens::SelectLens
    param_name :requester
    i18n_key "simple_form.options.work_job.requester"

    protected

    def possible_options
      [:any].concat(requesters)
    end

    def requesters
      Job.requester_options(community: context.current_community).to_a <<
        OpenStruct.new(id: "none", name: I18n.t("#{i18n_key}.none"))
    end
  end
end
