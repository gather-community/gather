# frozen_string_literal: true

# == Schema Information
#
# Table name: subscription_messaging_topups
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  stripe_id    :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :messaging_topup, class: "Subscription::MessagingTopup" do
    community
    sequence(:stripe_id) { |n| "sub_topup#{n}" }
  end
end
