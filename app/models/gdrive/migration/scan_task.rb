# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_scan_tasks
#
#  id         :bigint           not null, primary key
#  page_token :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :integer          not null
#  folder_id  :string(128)
#  scan_id    :bigint           not null
#
# Indexes
#
#  index_gdrive_migration_scan_tasks_on_scan_id  (scan_id)
#
# Foreign Keys
#
#  fk_rails_...  (scan_id => gdrive_migration_scans.id)
#
module GDrive
  module Migration
    class ScanTask < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :scan, inverse_of: :scan_tasks
    end
  end
end
