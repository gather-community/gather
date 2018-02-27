require "rails_helper"

describe DeviseMailer do
  describe "reset_password_instructions" do
    let(:token) { "628ab7dc26" }
    let(:mail) { described_class.reset_password_instructions(user, token).deliver_now }

    context "with regular user" do
      let(:user) { create(:user) }

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

    context "with fake user" do
      let(:user) { create(:user, fake: true) }

      it "returns nil" do
        expect(mail).to be_nil
      end
    end
  end
end
