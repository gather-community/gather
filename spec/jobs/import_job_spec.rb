# frozen_string_literal: true

require "rails_helper"

# Tests the generic ImportJob class using Meals::Import
describe ImportJob do
  include_context "jobs"

  let(:community) { Defaults.community }

  context "happy path" do
    let(:meal_import) { create(:meal_import, community: community, csv: "") }

    it "calls import" do
      perform_job(class_name: "Meals::Import", id: meal_import.id)
      expect(meal_import.reload.errors_by_row).to eq("0" => ["File is empty"])
    end
  end

  context "with unhandled error" do
    # nil CSV will raise error b/c no file will be attached in factory
    let(:meal_import) { create(:meal_import, community: community, csv: nil) }

    it "sets crashed status and sends error notification" do
      emails = email_sent_by do
        perform_job(class_name: "Meals::Import", id: meal_import.id)
      end
      expect(meal_import.reload.status).to eq("crashed")
      expect(emails[0].body.encoded).to match(/DelegationError/)
    end
  end
end
