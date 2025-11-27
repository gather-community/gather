# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_types
#
#  id             :bigint           not null, primary key
#  category       :string(32)
#  cluster_id     :bigint           not null
#  community_id   :bigint           not null
#  created_at     :datetime         not null
#  deactivated_at :datetime
#  name           :string(32)       not null
#  updated_at     :datetime         not null
#
require "rails_helper"

describe Meals::Type do
  it "has valid factory" do
    create(:meal_type)
  end
end
