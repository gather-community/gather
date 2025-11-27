# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id         :bigint           not null, primary key
#  cluster_id :bigint           not null
#  created_at :datetime         not null
#  name       :string           not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :domain do
    sequence(:name) { |i| "domain#{i}.example.com" }

    after(:build) do |domain|
      domain.communities << Defaults.community if domain.communities.none?
    end
  end
end
