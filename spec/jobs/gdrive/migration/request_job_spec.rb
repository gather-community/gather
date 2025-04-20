# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::RequestJob do
  include_context "jobs"

  let(:community) { Defaults.community }
  let!(:config) { create(:gdrive_config, community: community) }
  let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: config.org_user_id, access_token: "ya29.a0AeXRPp4aH2VpuozhQivLX5-PPaWW7PjN3xNMqR33NK3y-Xl-XEVZ235wFIqbH4Qqrk3uVWEOOTIBWjssw_NY77LlbBYEzZyGLW5gAHZd-w90_sdJ49i7whuP0N1MGHNUgrspbLiBVjgFq8ftHclc8T0i2ZStGO7jDKRytnRrdugaCgYKAfsSARESFQHGX2MiET46Y49afvFZMQQAC-fVfg0178") }
  let!(:operation) { create(:gdrive_migration_operation, community: community) }
  let!(:file1) { create(:gdrive_migration_file, operation: operation, owner: "a@gmail.com") }
  let!(:file2) { create(:gdrive_migration_file, operation: operation, owner: "a@gmail.com") }
  let!(:file3) { create(:gdrive_migration_file, operation: operation, owner: "b@gmail.com") }
  subject(:job) do
    described_class.new(cluster_id: Defaults.cluster.id, operation_id: operation.id,
      google_emails: ["a@gmail.com", "b@gmail.com"])
  end

  it "works" do
    VCR.use_cassette("gdrive/migration/request_job/happy_path") do
      request_ids = []

      expect(described_class).to receive(:random_drive_id).twice.and_return("01234567", "890abcde")
      expect(GDrive::Migration::Mailer).to receive(:migration_request).twice do |request|
        request_ids << request.id
        double(deliver_now: nil)
      end

      perform_job
      expect(GDrive::Migration::Request.count).to eq(2)
      expect(GDrive::Migration::Request.pluck(:id)).to match_array(request_ids)

      request1 = operation.requests.find_by(google_email: "a@gmail.com")
      expect(request1.file_count).to eq(2)
      expect(request1.file_drop_drive_id).to eq("0AH1t4Om92eQGUk9PVA")
      expect(request1.file_drop_drive_name).to eq("Gather File Drop 01234567")

      request2 = operation.requests.find_by(google_email: "b@gmail.com")
      expect(request2.file_count).to eq(1)
      expect(request2.file_drop_drive_id).to eq("0ALuBmEiJY2YlUk9PVA")
      expect(request2.file_drop_drive_name).to eq("Gather File Drop 890abcde")
    end
  end

  context "when requests already exist" do
    let!(:request1) { create(:gdrive_migration_request, operation: operation, google_email: "a@gmail.com") }
    let!(:request2) { create(:gdrive_migration_request, operation: operation, google_email: "b@gmail.com") }

    it "doesn't send any new ones" do
      expect(GDrive::Migration::Request.count).to eq(2)
      perform_job
      expect(GDrive::Migration::Request.count).to eq(2)
    end
  end
end
