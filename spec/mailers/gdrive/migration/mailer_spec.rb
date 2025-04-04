# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::Mailer do
  # We should still send to user's main email even if they're inactive.
  let!(:operation) { create(:gdrive_migration_operation, contact_email: "john@example.com") }
  let(:request) do
    create(:gdrive_migration_request, operation: operation, google_email: "blorb@gmail.com")
  end
  let(:mail) { described_class.migration_request(request).deliver_now }

  describe "when google_email matches a user record" do
    let!(:user) { create(:user, :inactive, first_name: "Bing", last_name: "Borb", email: "blorb@example.com", google_email: "blorb@gmail.com") }

    it "builds mail properly" do
      expect(mail.to).to match_array(["blorb@example.com", "blorb@gmail.com"])
      expect(mail.reply_to).to eq(["john@example.com"])
      expect(mail.subject).to eq("[Action Required] Help Default reorganize its Google Drive files!")
      expect(mail.body).to match("Dear Bing Borb,")
    end
  end

  describe "when google_email doesn't match a user record" do
    let!(:user) { create(:user, :inactive, first_name: "Bing", last_name: "Borb", google_email: "zorb@example.com") }

    it "builds mail properly" do
      expect(mail.to).to match_array(["blorb@gmail.com"])
      expect(mail.body).to match("Dear blorb@gmail.com,")
    end
  end
end
