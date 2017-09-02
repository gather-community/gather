# Sends invites to the users with the given IDs.
module People
  class InviteJob < ApplicationJob
    attr_reader :community_id, :user_ids

    def initialize(community_id, user_ids)
      @community_id = community_id
      @user_ids = user_ids
    end

    def perform
      with_tenant_from_community_id(community_id) do
        User.find(user_ids).each(&:send_reset_password_instructions)
      end
    end

    private

    def users
      User.find(@user_ids)
    end
  end
end
