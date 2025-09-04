# frozen_string_literal: true

# == Schema Information
#
# Table name: clusters
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  name       :string(20)       not null
#  sso_secret :string           not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :cluster do
    sequence(:name) { |n| "Cluster #{n}" }
  end
end
