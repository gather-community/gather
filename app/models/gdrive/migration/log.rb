# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_logs
#
#  id           :bigint           not null, primary key
#  data         :jsonb
#  level        :string           not null
#  message      :text             not null
#  created_at   :datetime         not null
#  cluster_id   :bigint           not null
#  operation_id :bigint           not null
#
# Indexes
#
#  index_gdrive_migration_logs_on_cluster_id    (cluster_id)
#  index_gdrive_migration_logs_on_created_at    (created_at)
#  index_gdrive_migration_logs_on_operation_id  (operation_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (operation_id => gdrive_migration_operations.id)
#
module GDrive
  module Migration
    class Log < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, inverse_of: :logs
    end
  end
end
