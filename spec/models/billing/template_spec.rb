# frozen_string_literal: true

require "rails_helper"

describe Billing::Template do
  it "has a valid factory" do
    member_type = create(:member_type)
    create(:billing_template, member_types: [member_type])
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
    context "without associations" do
      let(:template) { create(:billing_template) }

      it "destroys cleanly" do
        template.destroy
      end
    end

    context "with member type" do
      let(:member_type) { create(:member_type) }
      let(:template) { create(:billing_template, member_types: [member_type]) }

      it "destroys cleanly but doesn't destroy member type" do
        template.destroy
        expect { member_type }.not_to raise_error
      end
    end
  end
end
