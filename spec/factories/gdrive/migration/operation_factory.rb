# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_operation, class: "GDrive::Migration::Operation" do
    community { Defaults.community }
    src_folder_id { "abc123" }
    dest_folder_id { "123abc" }
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
