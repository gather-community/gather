# frozen_string_literal: true

# == Schema Information
#
# Table name: group_memberships
#
#  id         :bigint           not null, primary key
#  cluster_id :bigint           not null
#  created_at :datetime         not null
#  group_id   :bigint           not null
#  kind       :string(32)       default("joiner"), not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
require "rails_helper"

describe Groups::Membership do
  it "has a valid factory" do
    create(:group_membership)
  end
end
