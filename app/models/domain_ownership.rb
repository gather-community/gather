# frozen_string_literal: true

# Connects a communitiy to a domain.
class DomainOwnership < ApplicationRecord
  acts_as_tenant :cluster

  belongs_to :domain, inverse_of: :ownerships
  belongs_to :community, inverse_of: :domain_ownerships

  after_destroy :destroy_domain_if_no_communities

  private

  def destroy_domain_if_no_communities
    if domain.reload.communities.empty?
      domain.destroy
    end
  end
end
