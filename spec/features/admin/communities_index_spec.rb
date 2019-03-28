# frozen_string_literal: true

require "rails_helper"

feature "communities index" do
  let!(:communityB) { create(:community, name: "Other Community") }
  let!(:actor) { create(:super_admin) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    # Generate some fake data to exercise the queries.
    create(:meal)
    create(:reservation)
    create(:work_shift)
    create(:transaction)

    login_as(actor, scope: :user)
  end

  scenario "happy path" do
    visit(communities_path)
    expect(page).to have_content("Default")
    expect(page).to have_content("Other Community")
  end
end
