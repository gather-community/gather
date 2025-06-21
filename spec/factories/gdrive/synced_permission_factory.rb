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
FactoryBot.define do
  factory :gdrive_synced_permission, class: "GDrive::SyncedPermission" do
    user
    association(:item, factory: :gdrive_item)
    sequence(:external_id) { |n| "xxxxx#{n}" }
    item_external_id { item.external_id }
    google_email { user.google_email }
    access_level { "reader" }
  end
end
