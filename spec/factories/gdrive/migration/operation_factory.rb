# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_operations
#
#  id                  :bigint           not null, primary key
#  active              :boolean          default(TRUE), not null
#  cluster_id          :integer          not null
#  community_id        :bigint           not null
#  contact_email       :string           not null
#  contact_name        :string           not null
#  created_at          :datetime         not null
#  dest_folder_id      :string(255)
#  src_folder_id       :string(255)
#  start_page_token    :string
#  updated_at          :datetime         not null
#  webhook_channel_id  :string
#  webhook_expires_at  :datetime
#  webhook_resource_id :string
#  webhook_secret      :string
#
FactoryBot.define do
  factory :gdrive_migration_operation, class: "GDrive::Migration::Operation" do
    community { Defaults.community }
    src_folder_id { "abc123abc123abc123abc123abc123abc123" }
    dest_folder_id { "123abcabc123abc123a" }
    contact_name { "John Johns" }
    contact_email { "foo@example.com" }

    trait :webhook_registered do
      webhook_channel_id { "b0801a4c-4437-4284-b723-035c7c7f87f8" }
      webhook_secret { "7ca1eda696d682802edf3d3056ca03fd" }
      webhook_resource_id { "030dP89w23Mzw28mQBrIu00iMXg" }
      webhook_expires_at { Time.current + 1.hour }
      start_page_token { "12345" }
    end

    trait :webhook_not_registered do
      webhook_channel_id { nil }
      webhook_secret { nil }
      webhook_resource_id { nil }
      webhook_expires_at { nil }
      start_page_token { nil }
    end
  end
end
