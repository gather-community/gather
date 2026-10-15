# frozen_string_literal: true

require "rails_helper"

# Who gets a notification is worked out by Notifications::Recipients; see recipients_spec.rb.
# This covers what ApplicationMailer#mail adds on top.
describe ApplicationMailer do
  # Sample mailers for testing only.
  class SampleMailer < ApplicationMailer
    # A required kind, which can go to several people on one message.
    def sample(recipients)
      @community = Array.wrap(recipients).first.community
      mail(to: recipients, subject: "Test", body: "Test", notification: :meal_message)
    end

    # A configurable kind, which goes to one recipient passed with `with(recipient:)`.
    def configurable
      @community = recipient.community
      mail(to: recipient, subject: "Test", body: "Test", notification: :meal_reminder)
    end
  end

  class SampleUnlistedMailer < ApplicationMailer
    def sample(recipients)
      @community = recipients.first.community
      mail(to: recipients, subject: "Test", body: "Test")
    end
  end

  let(:adult1) { create(:user) }
  let(:adult2) { create(:user) }
  let(:household) { create(:household, users: [adult1, adult2]) }

  it "raises for a mailer action that isn't in the notification catalog" do
    expect { SampleUnlistedMailer.sample([adult1]).deliver_now }
      .to raise_error(/SampleUnlistedMailer#sample must be listed in Notifications::Catalog/)
  end

  describe "required notifications" do
    let(:mail) { SampleMailer.sample([household]).deliver_now }

    it "go to everyone on one message, resolved by Notifications::Recipients" do
      expect(mail.to).to contain_exactly(adult1.email, adult2.email)
    end

    it "have no unsubscribe header" do
      expect(mail["List-Unsubscribe"]).to be_nil
    end
  end

  describe "configurable notifications" do
    it "raise without a recipient" do
      expect { SampleMailer.configurable.deliver_now }
        .to raise_error(ArgumentError, /with\(recipient: user\)/)
    end

    it "raise if the recipient would reach several people" do
      expect { SampleMailer.with(recipient: household).configurable.deliver_now }
        .to raise_error(ArgumentError, /must go to one user/)
    end

    it "aren't sent to a recipient who opted out, even if the caller didn't check" do
      adult1.update!(notification_prefs: {"meal_reminder" => {"email" => false}})
      expect(SampleMailer.with(recipient: adult1).configurable.deliver_now).to be_nil
    end

    it "carry a one-click unsubscribe header for the recipient" do
      mail = SampleMailer.with(recipient: adult1).configurable.deliver_now
      expect(mail.to).to eq([adult1.email])
      token = mail["List-Unsubscribe"].value[%r{/notifications/unsubscribe/([^>]+)>}, 1]
      unsubscribe = Notifications::Unsubscribe.from_token(token)
      expect(unsubscribe.user).to eq(adult1)
      expect(unsubscribe.kind.key).to eq(:meal_reminder)
      expect(mail["List-Unsubscribe-Post"].value).to eq("List-Unsubscribe=One-Click")
    end
  end
end
