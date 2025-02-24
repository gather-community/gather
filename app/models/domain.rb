# frozen_string_literal: true

# A domain owned by one or more communities.
# == Schema Information
#
# Table name: domains
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :bigint           not null
#
# Indexes
#
#  index_domains_on_cluster_id  (cluster_id)
#  index_domains_on_name        (name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#
class Domain < ApplicationRecord
  acts_as_tenant :cluster

  has_many :ownerships, class_name: "DomainOwnership", dependent: :destroy
  has_many :communities, through: :ownerships
  has_many :group_mailman_lists, class_name: "Groups::Mailman::List", dependent: :destroy

  scope :by_name, -> { alpha_order(:name) }
end
