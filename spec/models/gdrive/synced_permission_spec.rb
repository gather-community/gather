# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_synced_permissions
#
#  id               :bigint           not null, primary key
#  access_level     :string(32)       not null
#  cluster_id       :bigint           not null
#  created_at       :datetime         not null
#  external_id      :string           not null
#  google_email     :string(256)      not null
#  item_external_id :string(128)      not null
#  item_id          :integer          not null
#  updated_at       :datetime         not null
#  user_id          :integer          not null
#
require "rails_helper"

describe GDrive::SyncedPermission do
  it "has a valid factory" do
    create(:gdrive_synced_permission)
  end
end
