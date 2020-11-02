# frozen_string_literal: true

module People
  class MemberType < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :member_types
    has_many :households, inverse_of: :member_type, dependent: :nullify
    has_many :billing_template_member_types, class_name: "Billing::TemplateMemberType",
                                             inverse_of: :member_type, dependent: :destroy

    scope :in_community, ->(c) { where(community: c) }
    scope :by_name, -> { alpha_order(:name) }

    normalize_attributes :name

    validates :name, presence: true
  end
end
