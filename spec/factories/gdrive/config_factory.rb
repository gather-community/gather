# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_config, class: "GDrive::Config" do
    transient do
      # When testing using VCR, we should override these values as needed in the factory call, temporarily,
      # with a valid access_token taken from the development database.
      #
      # Once we have captured the request, remove the overridden values from the factory
      # call. We can leave the valid access_token in the cassette because access tokens are short-lived.
      access_token do
        "xxxx.A0ARrdaM_QONGK0_iSoCLftOlsCiWISzolJRKsAvL6Yvjz8V6RUq2cLOfmHA-gS2dEO3W_vFD5g8ChtNQpV5AfqQ8BIPtP_xDbjZavVZ1YeggP2EeWocrEDxdxVrByirrzfY32MExTnpimol114AB7BHdCxxxx"
      end
      refresh_token do
        "xxxx4HCOkvr0wgmNCgYIARAAGAQSNwF-L9IrEdybQAql6Z9OiwLdUuPLUR-dl8H5DhX8SoL_IkITiJ3m64HbqOMVOIFnK52YQ8Jxxxx"
      end
      expiration_time_millis { (Time.now + 1.day).to_i * 1000 }
    end
    community { Defaults.community }
    client_id { "xxxxxxxxxxxxxx-qufsbvlpl758tmfv217tlq2qf30haflo.apps.googleusercontent.com" }
    client_secret { "xxxxxxxx" }
    api_key { "xxxxxxxx" }
    org_user_id { "abc123@gmail.com" }
    token do
      {
        # This is not a secret.
        client_id: "xxxxxxxxxxxxxx-qufsbvlpl758tmfv217tlq2qf30haflo.apps.googleusercontent.com",
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
