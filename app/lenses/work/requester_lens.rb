module Work
  class RequesterLens < ApplicationLens
    param_name :requester

    def render
      i18n_key = "simple_form.options.work_job.requester"
      requesters = People::Group.all.to_a
      requesters << OpenStruct.new(id: "none", name: I18n.t("#{i18n_key}.none"))
      option_tags = h.options_from_collection_for_select(requesters, :id, :name, value)
      h.select_tag(param_name, option_tags,
        prompt: I18n.t("#{i18n_key}.any"),
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name
      )
    end
  end
end
