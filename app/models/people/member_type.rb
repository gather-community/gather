# frozen_string_literal: true

module People
  class MemberType < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :member_types

    normalize_attributes :name

    validates :name, presence: true
  end
end
