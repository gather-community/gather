# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_token, class: "GDrive::Token" do
    association :gdrive_config, factory: :gdrive_main_config
    google_user_id { "a@example.com" }
    data { "tokendata" }
  end
end
