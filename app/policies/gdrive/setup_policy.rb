# frozen_string_literal: true

module GDrive
  class SetupPolicy < ApplicationPolicy
    # We use the current community as the record since there is no GDrive auth class but we do
    # want to deny access to admins from other communities.
    alias community record

    def setup?
      active_admin?
    end
  end
end
