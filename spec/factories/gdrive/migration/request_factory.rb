# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_requests
#
#  id                   :bigint           not null, primary key
#  cluster_id           :bigint           not null
#  created_at           :datetime         not null
#  error_count          :integer          default(0), not null
#  file_count           :integer          not null
#  file_drop_drive_id   :string(128)
#  file_drop_drive_name :string(128)
#  google_email         :string(255)      not null
#  operation_id         :bigint           not null
#  opt_out_reason       :text
#  status               :string(16)       default("new"), not null
#  token                :string           not null
#  updated_at           :datetime         not null
#
FactoryBot.define do
  factory :gdrive_migration_request, class: "GDrive::Migration::Request" do
    association(:operation, factory: :gdrive_migration_operation)
    google_email { "foo@gmail.com" }
    file_count { 42 }
    status { "new" }
    file_drop_drive_id { SecureRandom.hex(32) }
    file_drop_drive_name { "Gather File Drop #{SecureRandom.hex(6)}" }
  end
end
