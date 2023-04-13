# frozen_string_literal: true

class SingleSignOnPolicy < ApplicationPolicy
  # We use the current community as the record since there is no SingleSignOn class but we do
  # want to deny access to users from other communities.
  alias community record

  def sign_on?
    active_in_community?
  end
end
