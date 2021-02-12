# frozen_string_literal: true

class SettingsPolicy < ApplicationPolicy
  # We use the current community as the record since there is no settings class but we do
  # want to deny access to admins from other communities.
  alias community record

  def index?
    active_admin?
  end

  def show?
    active_admin?
  end

  def update?
    active_admin?
  end
end
