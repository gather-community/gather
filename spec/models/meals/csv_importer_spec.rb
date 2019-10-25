# frozen_string_literal: true

require "rails_helper"

describe Meals::CsvImporter do
  let(:importer) { described_class.new(file).tap(&:import) }

  context "with empty file" do
    let(:file) { prepare_expectation("empty.csv") }

    it "returns error" do
      expect(importer.errors).to eq(0 => ["File is empty"])
    end
  end
end
