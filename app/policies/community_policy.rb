class CommunityPolicy < ApplicationPolicy
  def show?
    own_cluster_record? || active_super_admin?
  end

  def update?
    active_admin?
  end
end
