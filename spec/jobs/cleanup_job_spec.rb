# frozen_string_literal: true

require "rails_helper"

describe CleanupJob do
  include_context "jobs"

  context "with unattached blobs" do
    let!(:user) { Timecop.freeze(-1.day) { create(:user, :with_photo) } }
    let!(:new_blob) do
      ActiveStorage::Blob.create_and_upload!(io: File.open(fixture_file_path("chomsky.jpg")),
                                             filename: "chomsky.jpg")
    end
    let!(:old_blob) do
      Timecop.freeze(-1.day) do
        ActiveStorage::Blob.create_and_upload!(io: File.open(fixture_file_path("cooper.jpg")),
                                               filename: "cooper.jpg")
      end
    end

    it "deletes old unattached blobs only" do
      perform_job
      expect(user.reload.photo.blob).not_to be_nil
      expect { new_blob.reload }.not_to raise_error
      expect { old_blob.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
