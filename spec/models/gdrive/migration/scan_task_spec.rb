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
require "rails_helper"

describe GDrive::Migration::ScanTask do
  it "has a valid factory" do
    create(:gdrive_migration_scan_task)
  end
end
