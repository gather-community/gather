# frozen_string_literal: true

require "rails_helper"

describe "community admin page", js: true do
  let!(:actor) { create(:super_admin) }
  let!(:target_community) { create(:community, name: "Testy Coho", slug: "testy-coho") }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "shows community details" do
    visit(admin_community_path(target_community))
    expect(page).to have_title("Testy Coho")
    expect(page).to have_content("testy-coho")
  end

  scenario "delete is blocked when wrong slug entered" do
    visit(admin_community_path(target_community))
    click_on("Delete")
    fill_in_modal("wrong-slug")
    click_modal_button
    expect(page).to have_current_path(admin_community_path(target_community))
    expect(Community.exists?(target_community.id)).to be(true)
  end

  scenario "delete proceeds when correct slug entered" do
    visit(admin_community_path(target_community))
    click_on("Delete")
    fill_in_modal(target_community.slug)
    click_modal_button
    expect(page).to have_current_path(communities_path)
    expect(page).to have_content("is being deleted")
  end
end
