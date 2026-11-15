# frozen_string_literal: true

module Admin
  # Governs /admin and the footer's Admin link: allowed for anyone who can see at least one operator page.
  # Authorized headlessly (the record is %i[admin home]).
  class HomePolicy < ApplicationPolicy
    def show?
      CommunityPolicy.new(user, Community.new).index? ||
        Communities::SignupPolicy.new(user, Communities::Signup).index? ||
        DomainPolicy.new(user, :domain).index? ||
        FeatureFlagPolicy.new(user, :feature_flag).index?
    end
  end
end
