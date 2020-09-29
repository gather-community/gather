# frozen_string_literal: true

module People
  class Memorial < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :user, inverse_of: :memorial
    has_many :messages, class_name: "People::MemorialMessage", inverse_of: :memorial, dependent: :destroy

    scope :in_community, ->(c) { joins(:user).merge(User.in_community(c)) }
    scope :by_user_name, -> { joins(:user).merge(User.by_name) }

    delegate :community, to: :user

    normalize_attributes :obituary

    validates :birth_year, :death_year, :user_id, presence: true
    validates :user_id, uniqueness: true
  end
end
