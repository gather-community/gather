# frozen_string_literal: true

module Groups
  # Represents a choice by a user to opt out of an 'everybody' group.
  class OptOut < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :group, inverse_of: :opt_outs
    belongs_to :user
  end
end
