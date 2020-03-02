# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::SingleSignOnJob do
  include_context "jobs"

  context "action: :update" do
    let(:user) { create(:user, id: 2540, email: "x@y.com", first_name: "X", last_name: "Lu") }
    subject!(:job) { described_class.new(user_id: user.id, action: :update) }

    it "calls appropriate url" do
      VCR.use_cassette("groups/mailman/sso/update") do
        perform_job
      end
    end
  end

  context "action: :sign_out" do
    context "with matching user" do
      let(:user) { create(:user, id: 2540) }
      subject!(:job) { described_class.new(user_id: user.id, action: :sign_out) }

      it "calls appropriate url" do
        VCR.use_cassette("groups/mailman/sso/sign_out/matching") do
          perform_job
        end
      end
    end

    context "without matching user" do
      let(:user) { create(:user, id: 2541) }
      subject!(:job) { described_class.new(user_id: user.id, action: :sign_out) }

      it "calls appropriate url and handles error" do
        VCR.use_cassette("groups/mailman/sso/sign_out/no_matching") do
          perform_job
        end
      end
    end
  end
end
