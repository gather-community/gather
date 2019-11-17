# frozen_string_literal: true

require "rails_helper"

describe AttachmentFormable do
  describe "validation" do
    subject(:model) { build(:user, :with_photo, photo_path: path) }

    describe "validates_attachment_content_type" do
      context "with valid type" do
        let(:path) { fixture_file_path("chomsky.jpg") }
        it { is_expected.to be_valid }
      end

      context "with invalid type" do
        let(:path) { fixture_file_path("article.pdf") }
        it { is_expected.to have_errors(photo: "has incorrect type") }
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
        it { is_expected.to have_errors(photo: "is too big") }
      end

      context "with no attachment" do
        subject(:model) { build(:user) }
        it { is_expected.to be_valid }
      end
    end
  end
end
