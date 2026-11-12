# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_requests
#
#  id                   :bigint           not null, primary key
#  cluster_id           :bigint           not null
#  created_at           :datetime         not null
#  error_count          :integer          default(0), not null
#  expired_at           :datetime
#  file_count           :integer          not null
#  file_drop_drive_id   :string(128)
#  file_drop_drive_name :string(128)
#  google_email         :string(255)      not null
#  operation_id         :bigint           not null
#  opt_out_reason       :text
#  status               :string(16)       default("new"), not null
#  token                :string           not null
#  updated_at           :datetime         not null
#
require "rails_helper"

describe GDrive::Migration::Request do
  it "has a valid factory" do
    create(:gdrive_migration_request)
  end

  describe "expiry" do
    let(:operation) { create(:gdrive_migration_operation) }
    let!(:fresh) do
      create(:gdrive_migration_request, operation: operation, google_email: "fresh@example.com")
    end
    let!(:old) do
      create(:gdrive_migration_request, operation: operation, google_email: "old@example.com",
        created_at: 31.days.ago)
    end
    let!(:cleaned_up) do
      create(:gdrive_migration_request, operation: operation, google_email: "done@example.com",
        created_at: 40.days.ago, expired_at: 5.days.ago)
    end

    it "expires a link 30 days after it's sent, before it's cleaned up" do
      expect(fresh).not_to be_expired
      expect(fresh).to be_active
      expect(old).to be_expired
      expect(old).not_to be_active
      expect(cleaned_up).to be_expired
    end

    it "finds requests due for clean-up" do
      expect(described_class.due_to_expire).to contain_exactly(old)
    end
  end
end
