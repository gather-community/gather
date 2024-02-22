# frozen_string_literal: true

require "rails_helper"

describe "meal status manipulation", js: true do
  let(:actor) { create(:admin) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "with closed meal" do
    let!(:meal) { create(:meal, :closed) }

    scenario do
      visit(meal_path(meal))
      accept_confirm { click_link("Reopen") }
      expect(page).to have_success_alert("Meal reopened successfully")
    end
  end

  context "with auto_close_time in past" do
    let!(:meal) { create(:meal, :closed, auto_close_time: Time.current - 1.day) }

    scenario do
      visit(meal_path(meal))
      accept_confirm { click_link("Reopen") }
      expect(page).to have_alert("You can't reopen this meal because its auto-close time is in the past.")
    end
  end
end
