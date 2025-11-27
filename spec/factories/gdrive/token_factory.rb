# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_tokens
#
#  id               :bigint           not null, primary key
#  cluster_id       :bigint           not null
#  created_at       :datetime         not null
#  data             :text             not null
#  gdrive_config_id :bigint           not null
#  google_user_id   :string           not null
#  updated_at       :datetime         not null
#
FactoryBot.define do
  factory :gdrive_token, class: "GDrive::Token" do
    # When testing using VCR, we should override access_token as needed in the factory call, temporarily,
    # with a valid access_token taken from the development database.
    #
    # Once we have captured the request, remove the overridden values from the factory
    # call and update the cassette to match.
    transient do
      access_token { "ya29.xxx" }
    end
    association :gdrive_config, factory: :gdrive_config
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
