# frozen_string_literal: true

# Models a subscription of Gather product itself.
class Subscription < ApplicationRecord
  acts_as_tenant :cluster

  belongs_to :community, inverse_of: :subscription
end
