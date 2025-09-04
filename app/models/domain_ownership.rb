# frozen_string_literal: true

# == Schema Information
#
# Table name: domain_ownerships
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  created_at   :datetime         not null
#  domain_id    :bigint           not null
#  updated_at   :datetime         not null
#
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
