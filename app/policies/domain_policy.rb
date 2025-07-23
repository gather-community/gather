# frozen_string_literal: true

class DomainPolicy < ApplicationPolicy
  alias domain record

  class Scope < Scope
    def resolve
      allow_admins_only
    end
  end

  def index?
    active_admin?
  end

  def show?
    active_admin_for_at_least_one_record_community?
  end

  def new?
    active_admin?
  end

  def edit?
    false
  end

  def create?
    active_admin?
  end

  def update?
    false
  end

  def destroy?
    active_admin_for_all_record_communities? && Groups::Mailman::List.where(domain: record).none?
  end

  # Whether the user can attach various objects to this domain like email lists.
  def attach_to?
    # We allow even regular users to attach things when the domain is tied to (and only to)
    # their own community. Additional policies will generally apply, e.g.
    # we might check if they're a list manager.
    record_tied_to_user_community? && record_communities.one? || active_cluster_admin?
  end

  def permitted_attributes
    permitted = [:name]
    permitted << {community_ids: []} if user.global_role?(:cluster_admin) || user.global_role?(:super_admin)
    permitted
  end
end
