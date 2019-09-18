# frozen_string_literal: true

require "rails_helper"

feature "user show" do
  let(:actor) { create(:user) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  context "with past meals" do
    let(:user) { create(:user) }
    let!(:meal) do
      create(:meal, :with_menu, title: "Foodz", head_cook: user, served_at: Time.current - 4.months)
    end

    scenario do
      visit(user_path(user))
      expect(page).to have_title(user.decorate.full_name)
      expect(page).to have_content(user.email)
      expect(page).to have_content("Past Head Cook Meals")
      expect(page).to have_content("Foodz")
    end
  end

  # See the User class for more documentation on email confirmation.
  context "pending reconfirmation" do
    let(:actor) { create(:user, :pending_reconfirmation) }

    scenario "clicking resend instructions link" do
      visit(user_path(actor))
      emails = email_sent_by do
        click_link("Resend confirmation instructions")
        expect(page).to have_alert("Instructions sent.")
      end
      expect(emails.map(&:subject)).to eq(["Please Confirm Your Email Address"])
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
