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

  belongs_to :community
  belongs_to :domain, inverse_of: :ownerships
end
