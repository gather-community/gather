module People
  class UserLens < ApplicationLens
    def render
      selected_option_tag = if set[:user].present?
        user = context.policy_scope(User).find(set[:user])
        h.content_tag(:option, user.name, value: user.id, selected: "selected")
      else
        ""
      end

      h.select_tag("user", selected_option_tag,
        prompt: "All Users",
        class: "form-control",
        onchange: "this.form.submit();",
        data: {
          "select2-src" => "users",
          "select2-prompt" => t("select2_prompts.user"),
          "select2-variable-width" => "true",
          "select2-context" => "lens"
        }
      )
    end
  end
end
