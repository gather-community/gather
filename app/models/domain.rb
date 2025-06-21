# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id         :bigint           not null, primary key
#  cluster_id :bigint           not null
#  created_at :datetime         not null
#  name       :string           not null
#  updated_at :datetime         not null
#
# A domain owned by one or more communities.
class Domain < ApplicationRecord
  acts_as_tenant :cluster

  has_many :ownerships, class_name: "DomainOwnership", dependent: :destroy
  has_many :communities, through: :ownerships
  has_many :group_mailman_lists, class_name: "Groups::Mailman::List", dependent: :destroy

  scope :by_name, -> { alpha_order(:name) }
end
