# frozen_string_literal: true

require "rails_helper"

describe "meal messages", :perform_jobs do
  let(:formula) { create(:meal_formula, :with_two_roles) }
  let!(:meal) { create(:meal, formula: formula, asst_cooks: [create(:user)]) }
  let!(:user) { meal.head_cook }
  let!(:signup) { create_list(:meal_signup, 2, meal: meal, diner_counts: [2, 1]) }

  before do
    use_user_subdomain(user)
    login_as(meal.head_cook, scope: :user)
  end

  scenario "cancel meal" do
    email_sent = email_sent_by do
      visit(meal_path(meal))
      click_link("Cancel")
      fill_in("Message", with: "Foo bar")
      click_button("Send Message and Cancel Meal")
      expect(page).to have_content("Message sent successfully")
      expect(page).to have_content("This meal has been cancelled")
    end
    expect(email_sent.size).to eq(4) # Signed up households + team
  end

  scenario "abort cancellation" do
    email_sent = email_sent_by do
      visit(meal_path(meal))
      click_link("Cancel")
      click_button("Don't Cancel Meal")
      expect(page).to have_title(meal.title)
      expect(page).not_to have_content("This meal has been cancelled")
    end
    expect(email_sent.size).to eq(0)
  end
end
