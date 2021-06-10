# frozen_string_literal: true

require "rails_helper"

describe "communities index" do
  let!(:communityB) { create(:community, name: "Other Community") }
  let!(:actor) { create(:super_admin) }

  before do
    use_user_subdomain(actor)
    # Generate some fake data to exercise the queries.
    create(:meal)
    create(:event)
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
