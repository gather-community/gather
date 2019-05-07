# frozen_string_literal: true

require "rails_helper"

feature "email confirmation", js: true do
  let(:actor) { create(:admin) }
  let!(:household) { create(:household, name: "Gingerbread") }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  context "on create" do
    scenario "with invite" do
      visit(new_user_path)
      fill_in("First Name", with: "Foo")
      fill_in("Last Name", with: "Barre")
      fill_in("Email", with: "foo@example.com")
      select2("Ginger", from: "#user_household_id")
      fill_in("Mobile", with: "5556667777")
      click_on("Save & Invite")
      expect(page).to have_alert("User created and invited successfully.")
      emails = email_sent_by { process_queued_job }
      expect(emails.map(&:subject)).to eq(["Instructions for Signing in to Gather"])
      expect(User.find_by(email: "foo@example.com")).not_to be_confirmed
    end

    scenario "without invite" do
      visit(new_user_path)
      fill_in("First Name", with: "Foo")
      fill_in("Last Name", with: "Barre")
      fill_in("Email", with: "foo@example.com")
      select2("Ginger", from: "#user_household_id")
      fill_in("Mobile", with: "5556667777")
      click_on("Save")
      expect(page).to have_alert("User created successfully.")
      emails = email_sent_by { process_queued_job }
      expect(emails).to be_empty
      expect(User.find_by(email: "foo@example.com")).not_to be_confirmed
    end
  end
end
