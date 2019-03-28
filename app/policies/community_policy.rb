# frozen_string_literal: true

class CommunityPolicy < ApplicationPolicy
  def index?
    active_super_admin?
  end

  def show?
    own_cluster_record? || active_super_admin?
  end

  def update?
    active_admin?
  end
end
