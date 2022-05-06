# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_config, class: "GDrive::Config" do
    community
    google_id { "abc123@gmail.com" }
    token { "adfyfoat4373ahfpaw73g" }
  end
end
