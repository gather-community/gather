# frozen_string_literal: true

# Builds user scope based on a given scope name and optionally some extra data
class UserSelectScoper
  include ActiveModel::Model

  attr_accessor :scope_name, :actor, :community, :extra_data

  def resolve
    users = UserPolicy::Scope.new(actor, User).resolve.by_name
    case scope_name
    when "current_community_full_access"
      users.active.in_community(community).full_access
    when "guardians"
      users.active.in_community(community).can_be_guardian
    when "current_cluster_full_access"
      users.active.full_access
    when "specific_community_full_access"
      community_ids = extra_data.presence || community.id
      users.active.full_access.in_community(community_ids)
    when "current_community_all"
      users.active.in_community(community)
    when "current_community_inactive"
      users.inactive.in_community(community)
    else
      raise "invalid user select context"
    end
  end
end
