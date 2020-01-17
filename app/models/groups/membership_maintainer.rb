# frozen_string_literal: true

module Groups
  # Maintains correct group memberships when other models change.
  class MembershipMaintainer
    include Singleton

    def user_committed(user)
      return unless user.saved_change_to_deactivated_at? && user.inactive?
      user.group_memberships.destroy_all
    end
  end
end
