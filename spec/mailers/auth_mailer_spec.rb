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

  describe "google_id_changed" do
    let(:mail) { described_class.google_id_changed(user, old_google_email).deliver_now }
    let(:old_google_email) { "old@gmail.com" }

    it_behaves_like "returns nil with fake user"

    context "with regular user" do
      let(:user) { create(:user, google_email: "new@gmail.com") }

      it "sends to the main email with the old and new accounts" do
        expect(mail.to).to eq([user.email])
        expect(mail.subject).to eq("Your Google ID Was Changed")
        expect(mail.body.encoded).to include("Dear #{user.name}")
        expect(mail.body.encoded).to include("was changed from old@gmail.com to new@gmail.com")
        expect(mail.body.encoded).to include("If you didn't make this change")
      end

      context "when there was no old account" do
        let(:old_google_email) { nil }

        it "says the account was linked" do
          expect(mail.body.encoded).to include("The Google account new@gmail.com is now linked")
          expect(mail.body.encoded).not_to include("changed from")
        end
      end
    end
  end

  describe "google_id_cleared" do
    let(:mail) { described_class.google_id_cleared(user).deliver_now }

    it_behaves_like "returns nil with fake user"

    context "with regular user" do
      let(:user) { create(:user, google_email: nil) }

      it "says an admin removed it" do
        expect(mail.to).to eq([user.email])
        expect(mail.subject).to eq("Your Google ID Was Removed")
        expect(mail.body.encoded).to include("An administrator removed the Google account")
        expect(mail.body.encoded).not_to include("If you didn't make this change")
      end
    end
  end
end
