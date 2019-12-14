# frozen_string_literal: true

module Groups
  # Joins a user to a group.
  class Membership < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :group, inverse_of: :memberships
    belongs_to :user

    normalize_attributes :kind

    def member?
      kind == "member"
    end

    def manager?
      kind == "manager"
    end
  end
end
