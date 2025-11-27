# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriptions
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  created_at   :datetime         not null
#  stripe_id    :string           not null
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :subscription, class: "Subscription::Subscription" do
    community
    stripe_id { "sub_1234" }
  end
end
