# frozen_string_literal: true

module Groups
  module Mailman
    # Renders templates for Mailman. Customizes based on list_id. Mailman fetches them as needed.
    class TemplatesController < ApplicationController
      # We don't need to authenticate this since it's not showing any confidential information
      # and authentication would be a pain.
      skip_before_action :authenticate_user!
      skip_after_action :verify_authorized

      def show
        ActsAsTenant.without_tenant { @list = List.find_by(remote_id: params[:list_id]) }
        render(params[:template_name].tr(":", "_"))
      end
    end
  end
end
