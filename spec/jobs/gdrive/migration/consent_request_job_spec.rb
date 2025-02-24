# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::ConsentRequestJob do
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
    consent_request_ids = []
    expect(GDrive::Migration::Mailer).to receive(:consent_request).twice do |consent_request|
      consent_request_ids << consent_request.id
      double(deliver_now: nil)
    end

    perform_job
    expect(GDrive::Migration::ConsentRequest.count).to eq(2)
    expect(GDrive::Migration::ConsentRequest.pluck(:id)).to match_array(consent_request_ids)

    request1 = operation.consent_requests.find_by(google_email: "a@gmail.com")
    expect(request1.file_count).to eq(2)

    request2 = operation.consent_requests.find_by(google_email: "b@gmail.com")
    expect(request2.file_count).to eq(1)
  end
end
