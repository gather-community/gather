class CommunityPolicy < ApplicationPolicy
  def show?
    own_cluster_record?
  end

  def update?
    active_admin?
  end
end
