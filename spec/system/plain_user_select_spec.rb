# frozen_string_literal: true

require "rails_helper"

# Other specs cover the select2 variant
describe "plain user select", js: true do
  let!(:actor) { create(:user) }
  let!(:friend) { create(:user) }
  let!(:meal) do
    create(:meal, :with_menu, served_at: Time.current + 7.days, title: "Haggis", head_cook: friend)
  end

  before do
    use_user_subdomain(actor)
    Defaults.community.update!(settings: {people: {plain_user_selects: true}})
    login_as(actor, scope: :user)
  end

  scenario "form selects" do
    visit(edit_user_path(actor))
    select(friend.name, from: "Job Choosing Proxy")
    click_on("Save")
    expect_success
    click_on("Edit")
    expect(page).to have_select("Job Choosing Proxy", selected: friend.name)
  end

  scenario "lens selects" do
    visit(jobs_meals_path)
    select_lens(:user, actor.name)
    expect(page).not_to have_content("Haggis")
    select_lens(:user, friend.name)
    expect(page).to have_content("Haggis")
  end
end
