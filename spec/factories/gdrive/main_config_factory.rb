# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_main_config, class: "GDrive::MainConfig" do
    community { Defaults.community }
    client_id { "236482764-xxx.apps.googleusercontent.com" }
    client_secret { "xxxxxxxx" }
    org_user_id { "abc123@gmail.com" }
  end
end
