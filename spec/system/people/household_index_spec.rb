# frozen_string_literal: true

require "rails_helper"

describe "household index", js: true do
  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  let(:actor) { create(:user) }
  let!(:household1) { create(:household, name: "Alpha", unit_num_and_suffix: "2DEF") }
  let!(:household2) { create(:household, name: "Bravo", unit_num_and_suffix: "2-ABC") }
  let!(:household3) { create(:household, name: "Charlie", unit_num_and_suffix: "10 ABC") }
  let!(:household4) { create(:household, name: "Delta", unit_num_and_suffix: "1") }

  scenario "sort lens" do
    visit(households_path)
    expect(page).to have_content("Alpha")
    expect(page).to have_content("Bravo")
    expect(page).to have_content("2-DEF")
    expect(page).to have_content("10-ABC")
    expect(page).to have_content("2-ABC")
    expect(page.body.index("Alpha")).to be < page.body.index("Bravo")
    expect(page.body.index("Delta")).to be > page.body.index("Charlie")
    select_lens_and_wait(:sort, "By Unit")
    expect(page.body.index("Alpha")).to be > page.body.index("Bravo")
    expect(page.body.index("Delta")).to be < page.body.index("Charlie")
  end

  scenario "search lens" do
    visit(households_path)
    fill_in_lens_and_wait(:search, "alpha")
    expect(page).to have_content("Alpha")
    expect(page).not_to have_content("Bravo")
  end
end
