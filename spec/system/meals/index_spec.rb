# frozen_string_literal: true

require "rails_helper"

describe "meals index", js: true do
  let(:actor) { create(:user) }
  let(:community1) { Defaults.community }
  let!(:community2) { create(:community) }
  let!(:cook1) { create(:user, first_name: "Lorris") }
  let!(:cook2) { create(:user, last_name: "Dorcas") }
  let!(:meal1) do
    create(:meal, :with_menu, served_at: Time.current - 7.days, title: "Oysters")
  end
  let!(:meal2) do
    create(:meal, :with_menu, served_at: Time.current + 7.days, title: "Haggis", head_cook: cook2)
  end
  let!(:meal3) do
    create(:meal, :with_menu, served_at: Time.current + 7.days, title: "Brewis", community: community2)
  end
  let!(:meal4) do
    create(:meal, :with_menu, served_at: Time.current + 7.days, title: "Sandwiches", head_cook: cook1,
                              community: community2, communities: [community1, community2])
  end
  let!(:meal5) do
    create(:meal, :with_menu, :finalized, served_at: Time.current - 7.days, title: "Gruel", head_cook: cook1)
  end

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "community lens" do
    visit(meals_path)
    expect(page).to have_content("Haggis")
    expect(page).to have_content("Sandwiches")
    expect(page).not_to have_content("Brewis")
    expect(page).to have_echoed_url(%r{https?://#{community1.subdomain}\.})
    select_lens(:community, community1.name)
    expect(page).not_to have_content("Sandwiches")
    expect(page).to have_content("Haggis")
    expect(page).not_to have_content("Brewis")
    expect(page).to have_echoed_url(%r{https?://#{community1.subdomain}\.})
    select_lens(:community, community2.name)
    expect(page).to have_content("Sandwiches")
    expect(page).not_to have_content("Haggis")
    expect(page).not_to have_content("Brewis") # User is not invited. Details in meal policy spec.
    expect(page).to have_echoed_url(%r{https?://#{community2.subdomain}\.})
    select_lens(:community, "All Communities")
    expect(page).to have_content("Haggis")
    expect(page).to have_content("Sandwiches")
    expect(page).not_to have_content("Brewis")
    expect(page).to have_echoed_url(%r{https?://#{community2.subdomain}\.})
  end

  scenario "time lens" do
    visit(meals_path)
    expect(page).to have_content("Haggis")
    expect(page).not_to have_content("Oysters")
    expect(page).not_to have_content("Gruel")
    select_lens(:time, "Past")
    expect(page).not_to have_content("Haggis")
    expect(page).to have_content("Oysters")
    expect(page).to have_content("Gruel")
    select_lens(:time, "Finalizable")
    expect(page).not_to have_content("Gruel")
    expect(page).not_to have_content("Haggis")
    expect(page).to have_content("Oysters")
    select_lens(:time, "All Time")
    expect(page).to have_content("Haggis")
    expect(page).to have_content("Oysters")
    expect(page).to have_content("Gruel")
  end

  scenario "search" do
    visit(meals_path)
    expect(page).to have_content("Haggis")
    expect(page).to have_content("Sandwiches")
    fill_in_lens(:search, "Haggis")
    expect(page).not_to have_content("Sandwiches")
    expect(page).to have_content("Haggis")
    fill_in_lens(:search, "Lorris")
    expect(page).to have_content("Sandwiches")
    expect(page).not_to have_content("Haggis")
    fill_in_lens(:search, "Dorcas")
    expect(page).not_to have_content("Sandwiches")
    expect(page).to have_content("Haggis")
  end
end
