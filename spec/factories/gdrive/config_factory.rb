# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_config, class: "GDrive::Config" do
    transient do
      access_token do
        "xxxx.A0ARrdaM_QONGK0_iSoCLftOlsCiWISzolJRKsAvL6Yvjz8V6RUq2cLOfmHA-gS2dEO3W_vFD5g8ChtNQpV5AfqQ8BIPtP_xDbjZavVZ1YeggP2EeWocrEDxdxVrByirrzfY32MExTnpimol114AB7BHdCxxxx"
      end
      refresh_token do
        "xxxx4HCOkvr0wgmNCgYIARAAGAQSNwF-L9IrEdybQAql6Z9OiwLdUuPLUR-dl8H5DhX8SoL_IkITiJ3m64HbqOMVOIFnK52YQ8Jxxxx"
      end
      expiration_time_millis { (Time.now + 1.day).to_i * 1000 }
    end
    community { Defaults.community }
    google_id { "abc123@gmail.com" }
    token do
      {
        client_id: "302773344240-el7fiv7rk3re87v1sat9u7ckggd6cu1r.apps.googleusercontent.com",
        access_token: access_token,
        refresh_token: refresh_token,
        scope: [
          "email",
          "profile",
          "https://www.googleapis.com/auth/drive.file",
          "openid",
          "https://www.googleapis.com/auth/userinfo.profile",
          "https://www.googleapis.com/auth/userinfo.email"
        ],
        expiration_time_millis: expiration_time_millis
      }.to_json
    end
  end
end
