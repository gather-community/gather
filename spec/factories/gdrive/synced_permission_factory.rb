# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_synced_permission, class: "GDrive::SyncedPermission" do
    user
    association(:item, factory: :gdrive_item)
    sequence(:item_external_id) { |i| "xxx#{i}" }
    google_email { "foo@gmail.com" }
    access_level { "reader" }
  end
end
