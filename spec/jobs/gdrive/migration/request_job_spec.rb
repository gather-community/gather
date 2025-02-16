# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::RequestJob do
  include_context "jobs"

  let(:operation) { create(:gdrive_migration_operation) }
  let!(:file1) { create(:gdrive_migration_file, operation: operation, owner: "a@gmail.com") }
  let!(:file2) { create(:gdrive_migration_file, operation: operation, owner: "a@gmail.com") }
  let!(:file3) { create(:gdrive_migration_file, operation: operation, owner: "b@gmail.com") }
  subject(:job) do
    described_class.new(cluster_id: Defaults.cluster.id, operation_id: operation.id,
      google_emails: ["a@gmail.com", "b@gmail.com"])
  end

  it "works" do
    request_ids = []
    expect(GDrive::Migration::Mailer).to receive(:request).twice do |request|
      request_ids << request.id
      double(deliver_now: nil)
    end

    perform_job
    expect(GDrive::Migration::Request.count).to eq(2)
    expect(GDrive::Migration::Request.pluck(:id)).to match_array(request_ids)

    request1 = operation.requests.find_by(google_email: "a@gmail.com")
    expect(request1.file_count).to eq(2)

    request2 = operation.requests.find_by(google_email: "b@gmail.com")
    expect(request2.file_count).to eq(1)
  end
end
