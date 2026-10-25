# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriptions
#
#  id                              :bigint           not null, primary key
#  cluster_id                      :bigint           not null
#  community_id                    :bigint           not null
#  created_at                      :datetime         not null
#  payment_intent_next_action_type :string
#  payment_intent_status           :string
#  setup_intent_next_action_type   :string
#  setup_intent_status             :string
#  stripe_id                       :string           not null
#  stripe_status                   :string
#  sync_error                      :string
#  synced_at                       :datetime
#  updated_at                      :datetime         not null
#
FactoryBot.define do
  factory :subscription, class: "Subscription::Subscription" do
    community
    stripe_id { "sub_1234" }
  end
end
