# frozen_string_literal: true

require "rails_helper"

describe "meals jobs page", js: true do
  let(:actor) { create(:user) }
  let(:community1) { Defaults.community }
  let!(:cook1) { create(:user, first_name: "Lorris") }
  let!(:cook2) { create(:user, last_name: "Dorcas") }
  let!(:meal1) do
    create(:meal, :with_menu, served_at: Time.current - 7.days, title: "Oysters")
  end
  let!(:meal2) do
    create(:meal, :with_menu, served_at: Time.current + 7.days, title: "Haggis", head_cook: cook2)
  end
  let!(:meal3) do
    create(:meal, :with_menu, served_at: Time.current + 7.days, title: "Sandwiches", head_cook: cook1)
  end

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "time lens" do
    visit(jobs_meals_path)
    expect(page).to have_content("Haggis")
    expect(page).not_to have_content("Oysters")
    select_lens(:time, "Past")
    expect(page).not_to have_content("Haggis")
    expect(page).to have_content("Oysters")
    select_lens(:time, "All Time")
    expect(page).to have_content("Haggis")
    expect(page).to have_content("Oysters")
  end

  scenario "user lens" do
    visit(jobs_meals_path)
    expect(page).to have_content("Haggis")
    expect(page).to have_content("Sandwiches")
    select2_lens(:user, "Lorris")
    expect(page).not_to have_content("Haggis")
    expect(page).to have_content("Sandwiches")
    select2_lens(:user, "Dorcas")
    expect(page).to have_content("Haggis")
    expect(page).not_to have_content("Sandwiches")
  end
end
