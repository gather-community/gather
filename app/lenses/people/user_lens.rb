# frozen_string_literal: true

module People
  # Presents a select2 for filtering by a single user.
  class UserLens < Lens::Lens
    param_name :user

    def render
      h.select_tag(param_name, selected_option_tag,
        prompt: h.t("users.all_users"),
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name,
        data: {
          "select2-src": "users",
          "select2-prompt": I18n.t("select2.prompts.user"),
          "select2-variable-width": "true",
          "select2-context": "lens"
        })
    end

    private

    # Returns the tag that says 'All Users'. Remote select2s only need one actual option tag.
    def selected_option_tag
      if value.present?
        user = context.policy_scope(User).find(value)
        h.content_tag(:option, user.name, value: user.id, selected: "selected")
      else
        ""
      end
    end
  end
end
