# frozen_string_literal: true

# Presents a select2 for filtering by a single user.
class UserLens < Lens::Lens
  param_name :user

  def render
    current_community.settings.people.plain_user_selects? ? render_plain_select : render_select2
  end

  def user
    @user ||= User.find_by(id: value)
  end

  protected

  def select2_context
    raise NotImplementedError
  end

  private

  delegate :current_community, :current_user, to: :context

  def render_select2
    h.select_tag(param_name, selected_option_tag,
                 prompt: h.t("users.all_users"),
                 class: css_classes,
                 onchange: "this.form.submit();",
                 "data-param-name": param_name,
                 data: {
                   "select2-src": "/users",
                   "select2-prompt": I18n.t("select2.prompts.user"),
                   "select2-variable-width": "true",
                   "select2-context": select2_context
                 })
  end

  def render_plain_select
    users = UserSelectScoper.new(scope_name: select2_context, actor: current_user,
                                 community: current_community).resolve
    h.select_tag(param_name, h.options_from_collection_for_select(users, "id", "name", user&.id),
                 prompt: h.t("users.all_users"),
                 class: css_classes,
                 onchange: "this.form.submit();",
                 "data-param-name": param_name)
  end

  # Returns the tag that says 'All Users'. Remote select2s only need one actual option tag.
  def selected_option_tag
    if user.present?
      h.tag.option(user.name, value: user.id, selected: "selected")
    else
      ""
    end
  end
end
