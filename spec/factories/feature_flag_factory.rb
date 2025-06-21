# frozen_string_literal: true

# == Schema Information
#
# Table name: feature_flags
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  interface  :string           default("basic"), not null
#  name       :string           not null
#  status     :boolean
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :feature_flag do
    sequence(:name) { |i| "FF #{i}" }
  end
end
