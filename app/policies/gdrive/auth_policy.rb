# frozen_string_literal: true

module GDrive
  class AuthPolicy < ApplicationPolicy
    # We use the current community as the record since there is no GDrive auth class but we do
    # want to deny access to admins from other communities.
    alias community record

    def index?
      active_admin? && FeatureFlag.lookup(:gdrive).on?(user)
    end

    def callback?
      index?
    end
  end
end
