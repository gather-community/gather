# frozen_string_literal: true

# Connects a communitiy to a domain.
# == Schema Information
#
# Table name: domain_ownerships
#
#  id           :bigint           not null, primary key
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  domain_id    :bigint           not null
#
# Indexes
#
#  index_domain_ownerships_on_cluster_id    (cluster_id)
#  index_domain_ownerships_on_community_id  (community_id)
#  index_domain_ownerships_on_domain_id     (domain_id)
#  index_domain_ownerships_unique           (cluster_id,community_id,domain_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#  fk_rails_...  (domain_id => domains.id)
#
class DomainOwnership < ApplicationRecord
  acts_as_tenant :cluster

  belongs_to :community
  belongs_to :domain, inverse_of: :ownerships
end
