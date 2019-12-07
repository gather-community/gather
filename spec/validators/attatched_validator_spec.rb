# frozen_string_literal: true

require "rails_helper"

describe AttachedValidator do
  context "with file" do
    subject(:model) { build(:meal_import, csv: "foo") }
    it { is_expected.to be_valid }
  end

  context "with no file" do
    subject(:model) { build(:meal_import, csv: nil) }
    it { is_expected.to have_errors(file: "can't be blank") }
  end
end
