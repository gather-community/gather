# frozen_string_literal: true

module GDrive
# == Schema Information
#
# Table name: gdrive_configs
#
#  id            :bigint           not null, primary key
#  client_secret :string           not null
#  type          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  client_id     :string           not null
#  cluster_id    :bigint           not null
#  community_id  :bigint           not null
#  org_user_id   :string(255)
#
# Indexes
#
#  index_gdrive_configs_on_cluster_id             (cluster_id)
#  index_gdrive_configs_on_community_id_and_type  (community_id,type) UNIQUE
#  index_gdrive_configs_on_org_user_id            (org_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#
  # Stores configuration information for GDrive connection used for migration.
  class MigrationConfig < Config
    has_many :operations, class_name: "GDrive::Migration::Operation", foreign_key: :config_id,
      inverse_of: :config, dependent: :destroy

    # drive.file is the restricted, non-sensitive scope.
    def drive_api_scope
      "https://www.googleapis.com/auth/drive.file"
    end

    def active_operation
      operations.active.order(created_at: :desc).first
    end
  end
end
