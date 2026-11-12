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

  describe ".matching" do
    let!(:veg) { create(:meal_type, name: "Veg Curry") }
    let!(:chicken) { create(:meal_type, name: "Chicken") }

    it "matches the start of each word of the name" do
      expect(described_class.matching("cur")).to contain_exactly(veg)
      expect(described_class.matching("urry")).to be_empty
    end
  end
end
