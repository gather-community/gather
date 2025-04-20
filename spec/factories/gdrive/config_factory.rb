# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_config, class: "GDrive::Config" do
    community { Defaults.community }
    client_id { "236482764-xxx.apps.googleusercontent.com" }
    client_secret_to_write { "53VUKh3CKKWOgKY1yn4BaPfaDYpFXMweksU" }
    org_user_id { "abc123@gmail.com" }
  end
end
