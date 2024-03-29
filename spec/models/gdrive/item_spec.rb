# frozen_string_literal: true

require "rails_helper"

describe GDrive::Item do
  it "has a valid factory" do
    create(:gdrive_item)
  end

  # Our approach to destruction is to:
  # - Set the policy to only disallow deletions based on what users of various roles should be able
  #   to destroy given various combinations of existing associations.
  # - Set association `dependent` options to avoid DB constraint errors UNLESS the destroy is never allowed.
  # - In the model spec, assume destroy has been called and test for the appropriate behavior
  #   (dependent destruction, nullification, or error) for each foreign key.
  # - In the policy spec, test for the appropriate restrictions on destroy.
  # - In the feature spec, test the destruction/deactivation/activation happy paths.
  describe "destruction" do
    let!(:item) { create(:gdrive_item) }
    let!(:item_group) { create(:gdrive_item_group, item: item) }

    it "deletes cleanly" do
      item.destroy
      expect { item.reload }.to(raise_error(ActiveRecord::RecordNotFound))
    end
  end
end
