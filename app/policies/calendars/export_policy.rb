# frozen_string_literal: true

module Calendars
  class ExportPolicy < ApplicationPolicy
    attr_accessor :community_token
    alias community record

    # We pass a community as the record because the community is the key object when it comes
    # to authorization.
    def initialize(user, community, community_token: nil)
      self.community_token = community_token
      super(user, community)
    rescue Pundit::NotAuthorizedError => e
      # Suppress the not auth'd error if community_token given. User not required in this case.
      raise e if community_token.blank?
    end

    def index?
      active?
    end

    def personalized?
      index?
    end

    # Tests whether non-personalized "community" exports are allowed.
    def community?
      community.calendar_token == community_token
    end

    def reset_token?
      index?
    end
  end
end
