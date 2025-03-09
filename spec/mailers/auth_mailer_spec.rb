# frozen_string_literal: true

require "rails_helper"

describe AuthMailer do
  let(:token) { "628ab7dc26" }

  shared_examples_for "returns nil with fake user" do
    let(:user) { create(:user, fake: true) }

    it "returns nil" do
      expect(mail).to be_nil
    end
  end

  describe "reset_password_instructions" do
    let(:mail) { described_class.reset_password_instructions(user, token).deliver_now }

    it_behaves_like "returns nil with fake user"

    context "with regular user" do
      let(:user) { create(:user) }

      it "sets the right from and reply_to" do
        from_addr = Settings.email.from.match(/<(.+)>/)[1]
        expect(mail.from).to eq([from_addr])
        expect(mail.reply_to).to eq([from_addr])
      end

      it "sets the right recipients" do
        expect(mail.to).to eq([user.email])
      end

      it "renders the subject" do
        expect(mail.subject).to eq("Resetting Your Password")
      end

      it "renders the correct name and URL in the body" do
        expect(mail.body.encoded).to include("Dear #{user.name}")
        path = "/people/users/password/edit?reset_password_token=#{token}"
        expect(mail.body.encoded).to contain_apex_url(path)
      end
    end
  end

  describe "sign_in_invitation" do
    let(:mail) { described_class.sign_in_invitation(user, token).deliver_now }

    it_behaves_like "returns nil with fake user"

    context "with regular user" do
      let(:user) { create(:user) }

      it "sets the right recipients" do
        expect(mail.to).to eq([user.email])
      end

      it "renders the subject" do
        expect(mail.subject).to eq("Instructions for Signing in to Gather")
      end

      it "renders the correct name and URL in the body" do
        expect(mail.body.encoded).to include("Dear #{user.name}")
        expect(mail.body.encoded).to contain_apex_url("/?token=#{token}")
      end
    end

    context "with user with no email" do
      let(:user) { create(:user, :child) }

      before do
        user.update!(email: nil)
      end

      it "sends nothing" do
        expect(mail).to be_nil
      end
    end
  end
end
