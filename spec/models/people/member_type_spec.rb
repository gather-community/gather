# frozen_string_literal: true

# == Schema Information
#
# Table name: people_member_types
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  created_at   :datetime         not null
#  name         :string(64)       not null
#  updated_at   :datetime         not null
#
require "rails_helper"

describe(People::MemberType) do
  it "has valid factory" do
    create(:member_type)
  end

  # Our approach to destruction is to:
  # - Set the policy to only disallow deletions based on what users of various roles should be able
  #   to destroy given various combinations of existing associations.
  # - Set association `dependent` options to avoid DB constraint errors UNLESS the destroy is never allowed.
  # - In the model spec, assume destroy has been called and test for the appropriate behavior
  #   (dependent destruction, nullification, or error) for each foreign key.
  # - In the policy spec, test for the appropriate restrictions on destroy.
  # - In the feature spec, test the destruction/deactivation/activation happy paths.
  # - For fake users and households, destruction may happen when associations are present that would
  #   normally forbid it, but the deletion script can be ordered in such a way as to avoid problems by
  #   deleting dependent objects first, and then users and households.
  describe "destruction" do
    let!(:member_type) { create(:member_type) }

    context "with household" do
      let!(:household) { create(:household, member_type: member_type) }

      it "nullifies" do
        expect(household.member_type).to eq(member_type)
        member_type.destroy
        expect(household.reload.member_type).to be_nil
      end
    end
  end
end
