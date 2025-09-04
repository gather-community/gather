# frozen_string_literal: true

# == Schema Information
#
# Table name: communities
#
#  id             :integer          not null, primary key
#  abbrv          :string(2)
#  calendar_token :string           not null
#  cluster_id     :integer          not null
#  country_code   :string(2)        default("US"), not null
#  created_at     :datetime         not null
#  name           :string(20)       not null
#  settings       :jsonb
#  slug           :string           not null
#  sso_secret     :string           not null
#  updated_at     :datetime         not null
#
FactoryBot.define do
  factory :community do
    sequence(:name) { |n| "Community #{n}" }
    sequence(:abbrv) { |n| "C#{n % 10}" }
    sequence(:slug) { |n| "community#{n}" }
    country_code { "US" }
  end
end
