# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_configs
#
#  id            :bigint           not null, primary key
#  client_id     :string           not null
#  client_secret :string           not null
#  cluster_id    :bigint           not null
#  community_id  :bigint           not null
#  created_at    :datetime         not null
#  org_user_id   :string(255)
#  updated_at    :datetime         not null
#
FactoryBot.define do
  factory :gdrive_config, class: "GDrive::Config" do
    community { Defaults.community }
    client_id { "236482764-xxx.apps.googleusercontent.com" }
    client_secret_to_write { "53VUKh3CKKWOgKY1yn4BaPfaDYpFXMweksU" }
    org_user_id { "abc123@gmail.com" }
  end
end
