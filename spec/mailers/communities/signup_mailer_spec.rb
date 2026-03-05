# frozen_string_literal: true

require "rails_helper"

describe Communities::SignupMailer do
  let(:reviewer) { create(:user) }
  let(:signup) { create(:communities_signup, :approved, reviewed_by: reviewer) }

  describe "approval_created" do
    subject(:mail) { described_class.approval_created(signup).deliver_now }

    it "sets the right recipient" do
      expect(mail.to).to eq([reviewer.email])
    end

    it "renders the subject" do
      expect(mail.subject).to eq("Community setup complete: #{signup.community_name}")
    end

    it "renders the community details and signup URL in the body" do
      expect(mail.body.encoded).to include(signup.community_name)
      expect(mail.body.encoded).to include(signup.slug)
      expect(mail.body.encoded).to include(signup.contact_email)
      expect(mail.body.encoded).to contain_apex_url("/communities/signups/#{signup.id}/review")
    end
  end

  describe "approval_failed" do
    let(:signup) do
      create(:communities_signup, :approved, reviewed_by: reviewer, failure_message: "Something went wrong")
    end

    subject(:mail) { described_class.approval_failed(signup).deliver_now }

    it "sets the right recipient" do
      expect(mail.to).to eq([reviewer.email])
    end

    it "renders the subject" do
      expect(mail.subject).to eq("Community setup FAILED: #{signup.community_name}")
    end

    it "renders the error, community details, and signup URL in the body" do
      expect(mail.body.encoded).to include(signup.community_name)
      expect(mail.body.encoded).to include(signup.slug)
      expect(mail.body.encoded).to include(signup.contact_email)
      expect(mail.body.encoded).to include("Something went wrong")
      expect(mail.body.encoded).to contain_apex_url("/communities/signups/#{signup.id}/review")
    end
  end
end
