# frozen_string_literal: true

# == Schema Information
#
# Table name: clusters
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  name       :string(20)       not null
#  sso_secret :string           not null
#  updated_at :datetime         not null
#
# A group of related communities.
class Cluster < ApplicationRecord
  has_many :communities, inverse_of: :cluster, dependent: :destroy
  # Groups are cluster-scoped but not community-scoped, so they must be destroyed at cluster level.
  # Destroy communities first (above) so FK deps (affiliations, work_jobs, events, etc.) are gone.
  has_many :groups, class_name: "Groups::Group", dependent: :destroy
  # SyncedPermissions are intentionally not cascaded from User or Item (to allow post-deletion sync
  # lookups), so they must be cleaned up at the cluster level.
  has_many :gdrive_synced_permissions, class_name: "GDrive::SyncedPermission", dependent: :delete_all

  before_create :generate_sso_secret

  def multi_community?
    communities.count > 1
  end

  private

  def generate_sso_secret
    self.sso_secret = UniqueTokenGenerator.generate(self.class, :sso_secret, type: :hex32)
  end
end
