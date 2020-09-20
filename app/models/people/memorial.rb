# frozen_string_literal: true

module People
  class Memorial < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :user, inverse_of: :memorial

    scope :in_community, ->(c) { joins(:user).merge(User.in_community(c)) }
    scope :by_user_name, -> { joins(:user).merge(User.by_name) }

    delegate :community, to: :user
  end
end
