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
require "rails_helper"

describe Subscription::Subscription do
  it "has a valid factory" do
    create(:subscription)
  end
end
