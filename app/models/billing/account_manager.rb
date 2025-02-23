# frozen_string_literal: true

module Billing
  # Finds and creates accounts as necessary.
  class AccountManager
    include Singleton

    def account_for(household_id:, community_id:)
      Account.find_or_create_by!(household_id: household_id, community_id: community_id)
    end

    # Ensures account exists for given household in own community.
    # We don't auto-create accounts in other communities in cluster since those
    # are less likely to be needed. They will get created automatically by account_for if they are needed.
    def create_household_successful(household)
      return if household.skip_listener_action == :account_create

      account_for(household_id: household.id, community_id: household.community_id)
    end
  end
end
