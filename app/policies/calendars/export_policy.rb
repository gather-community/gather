# frozen_string_literal: true

module Calendars
  class ExportPolicy < ApplicationPolicy
    attr_accessor :community_token

    def initialize(user, record, community_token: nil)
      self.community_token = community_token
      super(user, record)
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

    def community?
      record.community_calendar_token == community_token
    end

    def reset_token?
      index?
    end
  end
end
