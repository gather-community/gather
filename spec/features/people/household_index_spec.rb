# frozen_string_literal: true

require "rails_helper"

feature "household index", js: true do
  around do |example|
    with_user_home_subdomain(actor) { example.run }
  end

  before do
    login_as(actor, scope: :user)
  end

  let(:actor) { create(:user) }
  let!(:household1) { create(:household, name: "Alpha", unit_num: 10) }
  let!(:household2) { create(:household, name: "Bravo", unit_num: 2) }

  scenario "sort lens" do
    visit(households_path)
    expect(page).to have_content("Alpha")
    expect(page).to have_content("Bravo")
    expect(page.body.index("Alpha")).to be < page.body.index("Bravo")
    select_lens_and_wait(:sort, "By Unit")
    expect(page.body.index("Alpha")).to be > page.body.index("Bravo")
  end

  scenario "search lens" do
    visit(households_path)
    fill_in_lens_and_wait(:search, "alpha")
    expect(page).to have_content("Alpha")
    expect(page).not_to have_content("Bravo")
  end
end
