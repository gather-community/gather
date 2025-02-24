# frozen_string_literal: true

class DomainPolicy < ApplicationPolicy
  # Whether the user can attach various objects to this domain like email lists.
  def attach_to?
    # We allow even regular users to attach things when the domain is tied to (and only to)
    # their own community. Additional policies will generally apply, e.g.
    # we might check if they're a list manager.
    (record_tied_to_user_community? && record_communities.one?) || active_cluster_admin?
  end
end
