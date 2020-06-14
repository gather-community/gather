# frozen_string_literal: true

# Connects a communitiy to a domain.
class DomainOwnership < ApplicationRecord
  acts_as_tenant :cluster

  belongs_to :community
  belongs_to :domain, inverse_of: :ownerships
end
