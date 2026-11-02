# frozen_string_literal: true

# Renders a page of users as the JSON the select2 user selects read (see ajax_select2.js):
# {results: [{id, name, details?}], meta: {more}}. Shared by the community user selects
# (UsersController) and the operator's cross-cluster search (Admin::FeatureFlagsController).
module UserSelectJson
  extend ActiveSupport::Concern

  PER_PAGE = 20

  private

  # `details` adds each user's community and email to the results. Only pass it where the viewer
  # is allowed to see emails for everyone the search can return.
  def render_user_select_json(users, details: false)
    users = users.page(params[:page]).per(PER_PAGE)
    render(json: users.decorate, meta: {more: users.next_page.present?}, root: "results",
      each_serializer: UserSerializer, hide_inactive_in_name: true, details: details)
  end
end
