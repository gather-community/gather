# frozen_string_literal: true

require "rails_helper"

describe GDrive::MigrationConfig do
  it "has valid factory" do
    create(:gdrive_migration_config)
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
    let!(:config) { create(:gdrive_migration_config) }

    context "with token" do
      let!(:token) { create(:gdrive_token, gdrive_config: config) }

      it "destroys config and token" do
        config.destroy
        expect(GDrive::Token.count).to be_zero
        expect { config.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "with operation" do
      let!(:operation) { create(:gdrive_migration_operation, config: config) }

      it "destroys config and operation" do
        config.destroy
        expect(GDrive::Migration::Operation.count).to be_zero
        expect { config.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
