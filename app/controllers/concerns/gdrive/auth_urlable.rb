# frozen_string_literal: true

module GDrive
  module AuthUrlable
    extend ActiveSupport::Concern

    def setup_auth_url(wrapper:)
      state = {community_id: current_community.id}
      @auth_url = wrapper.get_authorization_url(request: request, state: state,
        redirect_to: gdrive_home_url)
    end
  end
end