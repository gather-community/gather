require "rails_helper"

describe DeviseMailer do
  describe "reset_password_instructions" do
    let(:token) { "628ab7dc26" }
    let(:user) { create(:user) }
    let(:mail) { described_class.reset_password_instructions(user, token).deliver_now }

    it "sets the right recipients" do
      expect(mail.to).to eq([user.email])
    end

    it "renders the subject" do
      expect(mail.subject).to eq("Welcome to Gather!")
    end

    it "renders the correct name and URL in the body" do
      expect(mail.body.encoded).to include("Hello #{user.name}")
      expect(mail.body.encoded).to contain_community_url(user.community, "/?token=#{token}")
    end
  end
end
