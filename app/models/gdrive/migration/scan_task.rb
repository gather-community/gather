# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_scan_tasks
#
#  id         :bigint           not null, primary key
#  cluster_id :integer          not null
#  created_at :datetime         not null
#  folder_id  :string(128)
#  page_token :string
#  scan_id    :bigint           not null
#  updated_at :datetime         not null
#
module GDrive
  module Migration
    class ScanTask < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :scan, inverse_of: :scan_tasks
    end
  end
end
