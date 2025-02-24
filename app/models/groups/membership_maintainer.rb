# frozen_string_literal: true

module Groups
  # Maintains correct group memberships when other models change.
  class MembershipMaintainer
    include Singleton

    def update_user_successful(user)
      return unless user.saved_change_to_deactivated_at? && user.inactive?

      user.group_memberships.destroy_all
    end

    def destroy_groups_affiliation_successful(affiliation)
      Membership
        .joins(:user)
        .merge(::User.in_community(affiliation.community_id))
        .where(group_id: affiliation.group_id)
        .destroy_all
      affiliation.group.destroy if Group.exists?(affiliation.group_id) && affiliation.group.no_communities?
    end

    def update_household_successful(household)
      return unless household.saved_change_to_community_id?

      Membership
        .where(user: household.users.pluck(:id))
        .where("NOT EXISTS(SELECT id FROM group_affiliations
           WHERE group_id = group_memberships.group_id AND community_id = ?)", household.community_id)
        .destroy_all
    end
  end
end
