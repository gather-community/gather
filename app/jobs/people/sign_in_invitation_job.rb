# frozen_string_literal: true

module People
  # Sends invites to the users with the given IDs.
  class SignInInvitationJob < ApplicationJob
    attr_reader :community_id, :user_ids

    def initialize(community_id, user_ids)
      @community_id = community_id
      @user_ids = user_ids
    end

    def perform
      with_community(community) do
        # Need to scope to community so folks can't invite users in communities in other clusters.
        # (ActsAsTenant prevents other clusters).
        User.in_community(community).where(id: user_ids).each(&:send_reset_password_instructions)
      end
    end
  end
end
