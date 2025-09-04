# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_scans
#
#  id                 :bigint           not null, primary key
#  cancel_reason      :string(128)
#  cluster_id         :bigint           not null
#  created_at         :datetime         not null
#  error_count        :integer          default(0), not null
#  log_data           :jsonb
#  operation_id       :bigint           not null
#  scanned_file_count :integer          default(0), not null
#  scope              :string(16)       default("full"), not null
#  status             :string(32)       default("new"), not null
#  updated_at         :datetime         not null
#
require "rails_helper"

describe GDrive::Migration::Scan do
  it "has a valid factory" do
    create(:gdrive_migration_scan)
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
    let!(:scan) { create(:gdrive_migration_scan) }

    context "with task" do
      let!(:task) { create(:gdrive_migration_scan_task, scan: scan) }

      it "destroys scan and task" do
        scan.destroy
        expect(GDrive::Migration::ScanTask.count).to be_zero
        expect { scan.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
