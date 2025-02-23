# frozen_string_literal: true

require "rails_helper"

describe FileSizeValidator do
  subject(:model) { build(:user, :with_photo, photo_path: path) }

  context "with good file" do
    let(:path) { fixture_file_path("60kb.jpg") }
    it { is_expected.to be_valid }
  end

  context "with too big file" do
    let(:path) { fixture_file_path("9mb.jpg") }
    it { is_expected.to have_errors(photo: 'File is too big \\(maximum 8 MiB\\)') }
  end

  context "with no attachment" do
    subject(:model) { build(:user) }
    it { is_expected.to be_valid }
  end
end
