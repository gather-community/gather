# frozen_string_literal: true

require "rails_helper"

describe "gdrive item groups", js: true do
  include_context "gdrive"

  let(:actor) { create(:admin) }
  let!(:config) { create(:gdrive_config, org_user_id: "admin@example.com") }
  let!(:item) { create(:gdrive_item, gdrive_config: config) }
  let!(:linked_group) { create(:group, name: "Already Linked") }
  let!(:group) { create(:group, name: "Stuff") }

  before do
    create(:gdrive_item_group, item: item, group: linked_group)
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "adding a group" do
    visit(new_gdrive_item_group_path(item_id: item.id))
    expect(page).to have_css(".alert-warning", text: "Group managers can add members")
    expect(page).not_to have_select("Group", with_options: ["Already Linked"])

    click_on("Save")
    expect_validation_error

    select("Stuff", from: "Group")
    select("Viewer", from: "Access Level")
    click_on("Save")
    expect_success
    expect(item.item_groups.map(&:group)).to contain_exactly(linked_group, group)
  end

  scenario "adding a group that got access since the form was opened" do
    visit(new_gdrive_item_group_path(item_id: item.id))
    select("Stuff", from: "Group")
    select("Viewer", from: "Access Level")
    create(:gdrive_item_group, item: item, group: group)
    click_on("Save")
    expect_validation_error
    expect(page).to have_content("has already been taken")
  end
end
