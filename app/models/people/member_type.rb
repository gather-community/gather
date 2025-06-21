# frozen_string_literal: true

# == Schema Information
#
# Table name: people_member_types
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  created_at   :datetime         not null
#  name         :string(64)       not null
#  updated_at   :datetime         not null
#
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
