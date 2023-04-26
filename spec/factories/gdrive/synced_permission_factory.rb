# frozen_string_literal: true

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
