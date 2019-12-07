# frozen_string_literal: true

require "rails_helper"

describe ContentTypeValidator do
  subject(:model) { build(:user, :with_photo, photo_path: path) }

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
