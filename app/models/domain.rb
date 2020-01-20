# frozen_string_literal: true

# A domain owned by one or more communities.
class Domain < ApplicationRecord
  acts_as_tenant :cluster

  has_many :domain_ownerships
  has_many :communities, through: :domain_ownerships
end
