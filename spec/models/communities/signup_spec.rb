# frozen_string_literal: true

require "rails_helper"

describe Communities::Signup do
  it "upcases country_code on save" do
    signup = create(:communities_signup, country_code: "ca")
    expect(signup.country_code).to eq("CA")
  end

  describe "#retry!" do
    let(:retrier) { create(:user) }

    it "puts a failed signup back to creating under the new reviewer, keeping the approval message" do
      signup = create(:communities_signup, :failed)
      signup.retry!(retrier)
      signup.reload
      expect(signup).to be_creating
      expect(signup.failure_message).to be_nil
      expect(signup.reviewed_by).to eq(retrier)
      expect(signup.message).to eq("Welcome! We're excited to have you on board.")
    end

    it "raises for a signup that hasn't failed" do
      signup = create(:communities_signup, :creating)
      expect { signup.retry!(retrier) }.to raise_error(ArgumentError)
      expect(signup.reload).to be_creating
    end
  end
end
