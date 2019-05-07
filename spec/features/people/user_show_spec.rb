# frozen_string_literal: true

require "rails_helper"

feature "user show" do
  let(:actor) { create(:user) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  context "pending reconfirmation" do
    let(:actor) { create(:user, :pending_reconfirmation) }

    scenario "clicking resend instructions link" do
      visit(user_path(actor))
      emails = email_sent_by do
        click_link("Resend confirmation instructions")
        expect(page).to have_alert("Instructions sent.")
      end
      expect(emails.map(&:subject)).to eq(["Confirm Your Email"])
    end

    scenario "clicking resend instructions link" do
      original_email = actor.email
      visit(user_path(actor))
      click_link("Cancel change")
      expect(page).to have_alert("Email change canceled.")
      expect(actor.reload.unconfirmed_email).to be_nil
      expect(actor.email).to eq(original_email)
    end
  end
end
