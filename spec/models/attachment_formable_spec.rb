# frozen_string_literal: true

require "rails_helper"

describe AttachmentFormable do
  let(:path) { fixture_file_path("chomsky.jpg") }
  subject(:model) { create(:user, :with_photo, photo_path: path) }

  describe "photo_new_signed_id" do
    it "works" do
      model.photo_new_signed_id = "abc"
      expect(model.photo_new_signed_id).to eq("abc")
    end
  end

  describe "photo_destroy" do
    it "works" do
      model.photo_destroy = "1"
      model.save!
      expect(model.reload.photo).not_to be_attached
    end
  end
end
