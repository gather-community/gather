# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::SingleSignOnJob do
  include_context "jobs"

  let(:user) { create(:user, id: 2540, email: "x@y.com", first_name: "X", last_name: "Lu") }

  context "action: :update" do
    subject!(:job) { described_class.new(user_id: user.id, action: :update) }

    it "calls appropriate url" do
      VCR.use_cassette("groups/mailman/sso/update") do
        perform_job
      end
    end
  end

  context "action: :sign_out" do
    subject!(:job) { described_class.new(user_id: user.id, action: :sign_out) }

    it "calls appropriate url" do
      VCR.use_cassette("groups/mailman/sso/sign_out") do
        perform_job
      end
    end
  end
end
