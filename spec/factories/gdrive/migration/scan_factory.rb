# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_scans
#
#  id                 :bigint           not null, primary key
#  cancel_reason      :string(128)
#  cluster_id         :bigint           not null
#  created_at         :datetime         not null
#  error_count        :integer          default(0), not null
#  operation_id       :bigint           not null
#  scanned_file_count :integer          default(0), not null
#  scope              :string(16)       default("full"), not null
#  status             :string(32)       default("new"), not null
#  updated_at         :datetime         not null
#  log_data           :jsonb
#
FactoryBot.define do
  factory :gdrive_migration_scan, class: "GDrive::Migration::Scan" do
    association :operation, factory: :gdrive_migration_operation
  end
end
