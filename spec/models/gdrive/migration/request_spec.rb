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
require "rails_helper"

describe GDrive::Migration::Request do
  it "has a valid factory" do
    create(:gdrive_migration_request)
  end
end
