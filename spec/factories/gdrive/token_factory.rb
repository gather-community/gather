# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_token, class: "GDrive::Token" do
    transient do
      access_token { "ya29.xxx" }
    end
    association :gdrive_config, factory: :gdrive_main_config
    google_user_id { "a@example.com" }
    data do
      {
        "client_id" => "236482764-xxx.apps.googleusercontent.com",
        "access_token" => access_token,
        "refresh_token" => "xxx",
        "scope" => [
          "email",
          "https://www.googleapis.com/auth/drive",
          "https://www.googleapis.com/auth/userinfo.email",
          "openid"
        ],
        "expiration_time_millis" => (Time.current + 1.hour).to_i * 1000
      }.to_json
    end
  end
end
