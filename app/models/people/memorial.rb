# frozen_string_literal: true

module People
  class Memorial < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :user, inverse_of: :memorial

    delegate :community, to: :user
  end
end
