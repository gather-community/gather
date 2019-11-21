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

  describe "validation" do
    subject(:model) { build(:user, :with_photo, photo_path: path) }

    describe "validates_attachment_content_type" do
      context "with valid type" do
        let(:path) { fixture_file_path("chomsky.jpg") }
        it { is_expected.to be_valid }
      end

      context "with invalid type" do
        let(:path) { fixture_file_path("article.pdf") }
        it { is_expected.to have_errors(photo: "File is incorrect type") }
      end

      context "with no attachment" do
        subject(:model) { build(:user) }
        it { is_expected.to be_valid }
      end
    end

    describe "validates_attachment_size" do
      context "with good file" do
        let(:path) { fixture_file_path("60kb.jpg") }
        it { is_expected.to be_valid }
      end

      context "with too big file" do
        let(:path) { fixture_file_path("9mb.jpg") }
        it { is_expected.to have_errors(photo: "File is too big \\(maximum 8 MiB\\)") }
      end

      context "with no attachment" do
        subject(:model) { build(:user) }
        it { is_expected.to be_valid }
      end
    end
  end
end
