# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::RequestExpiryJob do
  include_context "jobs"

  let!(:config) { create(:gdrive_config, org_user_id: "drive.admin@example.com") }
  let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: "drive.admin@example.com") }
  let!(:operation) { create(:gdrive_migration_operation, community: config.community) }
  let!(:empty) { make_request("empty@example.com", "emptyDrive", 31.days.ago) }
  let!(:with_files) { make_request("files@example.com", "filesDrive", 31.days.ago) }
  let!(:recent) { make_request("recent@example.com", "recentDrive", 29.days.ago) }
  let(:files_in) { {"emptyDrive" => [], "filesDrive" => [Google::Apis::DriveV3::File.new(id: "f1")]} }

  def make_request(email, drive_id, created_at)
    create(:gdrive_migration_request, operation: operation, google_email: email,
      file_drop_drive_id: drive_id, created_at: created_at)
  end

  before do
    allow_any_instance_of(GDrive::Wrapper).to receive(:list_files) do |_wrapper, drive_id:, **|
      Google::Apis::DriveV3::FileList.new(files: files_in.fetch(drive_id))
    end
    allow_any_instance_of(GDrive::Wrapper).to receive(:list_permissions).and_return(
      Google::Apis::DriveV3::PermissionList.new(permissions: [
        Google::Apis::DriveV3::Permission.new(id: "orgPerm", email_address: "drive.admin@example.com"),
        Google::Apis::DriveV3::Permission.new(id: "filesPerm", email_address: "files@example.com")
      ])
    )
    allow_any_instance_of(GDrive::Wrapper).to receive(:delete_drive)
    allow_any_instance_of(GDrive::Wrapper).to receive(:delete_permission)
  end

  it "deletes empty drives, removes the requestee from drives with files, and leaves recent requests" do
    expect_any_instance_of(GDrive::Wrapper).to receive(:delete_drive).with("emptyDrive")
    expect_any_instance_of(GDrive::Wrapper).to receive(:delete_permission)
      .with("filesDrive", "filesPerm", supports_all_drives: true)

    perform_job

    expect(empty.reload).to have_attributes(file_drop_drive_id: nil, expired_at: be_present)
    expect(with_files.reload).to have_attributes(file_drop_drive_id: "filesDrive", expired_at: be_present)
    expect(recent.reload.expired_at).to be_nil
  end

  it "treats a drive that's already gone as cleaned up" do
    allow_any_instance_of(GDrive::Wrapper).to receive(:list_files)
      .and_raise(Google::Apis::ClientError.new("notFound: Shared drive not found: emptyDrive"))

    perform_job

    expect(empty.reload).to have_attributes(file_drop_drive_id: nil, expired_at: be_present)
  end

  it "reports other errors and tries again next time" do
    allow_any_instance_of(GDrive::Wrapper).to receive(:list_files)
      .and_raise(Google::Apis::ClientError.new("insufficientFilePermissions: nope"))
    expect(Gather::ErrorReporter.instance).to receive(:report).twice

    perform_job

    expect(empty.reload).to have_attributes(file_drop_drive_id: "emptyDrive", expired_at: nil)
    expect(with_files.reload.expired_at).to be_nil
  end
end
