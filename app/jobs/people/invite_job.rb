# Sends invites to the users with the given IDs.
module People
  class InviteJob < ApplicationJob
    attr_reader :user_ids

    def initialize(user_ids)
      @user_ids = user_ids
    end

    def perform
      @users = User.find(user_ids)
      @users.each { |u| u.send_reset_password_instructions }
    end

    private

    def error_report_data
      {user_ids: user_ids}
    end
  end
end
