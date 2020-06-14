# frozen_string_literal: true

# A domain owned by one or more communities.
class Domain < ApplicationRecord
  acts_as_tenant :cluster

  has_many :ownerships, class_name: "DomainOwnership", dependent: :destroy
  has_many :communities, through: :ownerships
  has_many :group_mailman_lists, class_name: "Groups::Mailman::List", dependent: :destroy

  scope :by_name, -> { alpha_order(:name) }
end
