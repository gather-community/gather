# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::RequestDecorator do
  let(:request) { create(:gdrive_migration_request, status: "opened") }
  subject(:decorated) { request.decorate }

  describe "#status_label" do
    it "shows the status" do
      expect(decorated.status_label).to eq("Opened")
    end

    it "notes when the link has expired" do
      request.update!(created_at: 31.days.ago)
      expect(decorated.status_label).to eq("Opened, link expired")
    end
  end

  describe "#file_drop_drive_link" do
    it "links to the drive" do
      expect(decorated.file_drop_drive_link).to have_css("a[href$='#{request.file_drop_drive_id}']",
        text: request.file_drop_drive_name)
    end

    it "shows just the name once the drive is deleted" do
      request.update!(file_drop_drive_id: nil)
      expect(decorated.file_drop_drive_link).to eq(request.file_drop_drive_name)
    end
  end
end
