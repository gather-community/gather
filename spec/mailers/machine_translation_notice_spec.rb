# frozen_string_literal: true

require "rails_helper"

# Emails in machine-translated locales say so above the footer (see the mailer layout). Emails can't render
# in another locale until it's translated, so this pretends English is machine-translated.
describe "machine translation notice in emails" do
  let(:user) { create(:user) }
  let(:notice) { "This email was translated automatically and may contain mistakes." }

  it "isn't on emails in locales people translated" do
    mail = AuthMailer.sign_in_invitation(user, "abc").deliver_now
    expect(mail.body.encoded).not_to include(notice)
  end

  it "is on emails in machine-translated locales" do
    stub_const("Gather::Locales::MACHINE_TRANSLATED", [:en])
    mail = AuthMailer.sign_in_invitation(user, "abc").deliver_now
    expect(mail.body.encoded).to include(notice)
  end
end
