# frozen_string_literal: true

module People
  # Sends invites to the users with the given IDs.
  class SignInInvitationJob < ApplicationJob
    attr_reader :community_id, :user_ids

    def perform(community_id, user_ids)
      @community_id = community_id
      @user_ids = user_ids

      with_cluster(community.cluster) do
        # Need to scope to community so folks can't invite users in communities in other clusters.
        # (ActsAsTenant prevents other clusters).
        User.in_community(community).where(id: user_ids).each do |user|
          token = user.reset_reset_password_token!
          AuthMailer.sign_in_invitation(user, token).deliver_now
        rescue ActiveRecord::StatementInvalid => e
          Gather::ErrorReporter.instance.report(e)
        end
      end
    end
  end
end
