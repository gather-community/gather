# frozen_string_literal: true

require "rails_helper"

describe "notification unsubscribe link", js: true do
  let(:user) { create(:user) }
  let(:kind) { People::NotificationCatalog.find(:meal_role_reminder) }
  let(:token) { People::NotificationUnsubscribe.token_for(user, kind) }

  before { use_user_subdomain(user) }

  scenario "confirming from the email link, without signing in" do
    visit(notification_unsubscribe_path(token: token))
    expect(page).to have_content("Stop sending “Reminders for my meal shifts” emails to #{user.email}?")
    expect(user.reload.notification_enabled?(:meal_role_reminder)).to be(true)

    click_button("Unsubscribe")
    expect(page).to have_content("We won't send “Reminders for my meal shifts” emails to #{user.email} any more.")
    expect(user.reload.notification_enabled?(:meal_role_reminder)).to be(false)

    visit(notification_unsubscribe_path(token: token))
    expect(page).to have_content("are already turned off")
    expect(page).not_to have_button("Unsubscribe")
  end

  scenario "with an invalid link" do
    visit(notification_unsubscribe_path(token: "nope"))
    expect(page).to have_content("This unsubscribe link isn't valid.")
    expect(page).to have_link("Notifications", href: notification_preferences_path)
  end
end
