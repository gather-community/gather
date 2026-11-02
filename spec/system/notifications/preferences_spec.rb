# frozen_string_literal: true

require "rails_helper"

describe "notification preferences", js: true do
  let(:actor) { create(:user) }
  let!(:garden) { create(:group, name: "Garden", joiners: [actor]) }
  let!(:garden_list) { create(:group_mailman_list, group: garden, name: "garden") }
  let!(:other) { create(:group, name: "Other") }
  let!(:other_list) { create(:group_mailman_list, group: other, name: "other") }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "turning a notification off and back on" do
    visit(notification_preferences_path)

    expect(page).to have_checked_field("Reminders for my meal shifts")
    expect(page).to have_checked_field("Reminders when a payment is due")
    expect(page).to have_checked_field("Messages and cancellation notices from a meal team", disabled: true)
    expect(page).not_to have_content("Warnings that my community may be deleted")

    uncheck("Reminders for my meal shifts")
    click_button("Save")
    expect(page).to have_success_alert("Your notification preferences have been saved.")
    expect(page).to have_unchecked_field("Reminders for my meal shifts")
    expect(page).to have_checked_field("Reminders for my jobs")
    expect(actor.reload.notification_prefs).to eq("meal_role_reminder" => {"email" => false})

    # Reload so the first save's success alert is gone. Otherwise the alert check below could
    # match it before the second save finishes.
    visit(notification_preferences_path)
    expect(page).not_to have_css(".alert-success")
    check("Reminders for my meal shifts")
    click_button("Save")
    expect(page).to have_success_alert("Your notification preferences have been saved.")
    expect(actor.reload.notification_prefs).to eq({})
  end

  scenario "email lists" do
    visit(notification_preferences_path)
    row = find("tr", text: "Garden")
    expect(row).to have_link("View", href: groups_group_path(garden))
    expect(row.find_link("View")[:target]).to eq("_blank")
    expect(page).not_to have_content("Other")
  end

  context "as admin" do
    let(:actor) { create(:admin) }

    scenario "shows the inactivity warning as essential" do
      visit(notification_preferences_path)
      expect(page).to have_checked_field("Warnings that my community may be deleted for inactivity",
        disabled: true)
    end
  end
end
