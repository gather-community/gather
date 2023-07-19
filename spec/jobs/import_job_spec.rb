# frozen_string_literal: true

require "rails_helper"

# Tests the generic ImportJob class using Meals::Import
describe ImportJob do
  include_context "jobs"

  let!(:community) { Defaults.community }
  let!(:meal_import) { create(:meal_import, community: community, csv: "") }
  subject(:job) { described_class.new(class_name: "Meals::Import", id: meal_import.id) }

  context "happy path" do
    it "calls import" do
      perform_job
      expect(meal_import.reload.errors_by_row).to eq("0" => ["File is empty"])
    end
  end

  context "with unhandled error" do
    it "sets crashed status" do
      with_env("STUB_IMPORT_ERROR" => "Unhandled error") do
        expect { perform_job }.to raise_error(StandardError)
        expect(meal_import.reload.status).to eq("crashed")
      end
    end
  end
end
