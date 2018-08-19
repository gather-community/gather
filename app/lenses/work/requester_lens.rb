# frozen_string_literal: true

module Work
  # For filtering work jobs based on requesting group.
  class RequesterLens < Lens::SelectLens
    param_name :requester
    i18n_key "simple_form.options.work_job.requester"
    select_prompt :any

    protected

    def option_tags
      h.options_from_collection_for_select(requesters, :id, :name, value)
    end

    def requesters
      People::Group.all.to_a << OpenStruct.new(id: "none", name: I18n.t("#{i18n_key}.none"))
    end
  end
end
