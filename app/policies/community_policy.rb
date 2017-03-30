class CommunityPolicy < ApplicationPolicy
  def update?
    active_admin?
  end
end
