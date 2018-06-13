module People
  class UserLens < ApplicationLens
    param_name :user

    def render
      selected_option_tag = if value.present?
        user = context.policy_scope(User).find(value)
        h.content_tag(:option, user.name, value: user.id, selected: "selected")
      else
        ""
      end

      h.select_tag(param_name, selected_option_tag,
        prompt: "All Users",
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name,
        data: {
          "select2-src": "users",
          "select2-prompt": I18n.t("select2.prompts.user"),
          "select2-variable-width": "true",
          "select2-context": "lens",
        }
      )
    end
  end
end
