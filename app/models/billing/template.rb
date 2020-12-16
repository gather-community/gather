# frozen_string_literal: true

module Billing
  # Represents a template of a transaction from which transactions can be created.
  class Template < ApplicationRecord
    include Transactable

    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :billing_templates
    has_many :template_member_types, class_name: "Billing::TemplateMemberType",
                                     inverse_of: :template, dependent: :destroy
    has_many :member_types, class_name: "People::MemberType", through: :template_member_types

    scope :in_community, ->(c) { where(community: c) }
    scope :by_description, -> { alpha_order(:description) }

    normalize_attributes :code, :description
  end
end
