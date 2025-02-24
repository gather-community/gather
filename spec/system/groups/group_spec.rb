# frozen_string_literal: true

require "rails_helper"

describe "groups", js: true do
  let!(:group1) { create(:group, name: "Knitting Club", availability: "open", kind: "club") }
  let!(:group2) { create(:group, name: "Meals Committee", availability: "closed", kind: "committee") }
  let!(:group3) { create(:group, name: "All Hands", availability: "everybody", kind: "group") }
  let!(:group4) { create(:group, :inactive, name: "Fun Team", availability: "open", kind: "team") }
  let!(:manager1) { create(:group_membership, group: group1, kind: "manager").user }
  let!(:user1) { create(:user) }
  let!(:user2) { create(:user) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "as admin" do
    let(:actor) { create(:admin) }

    scenario "index" do
      visit(groups_groups_path)
      expect(page).to have_title("Groups")
      expect(page).to have_css("table.index tr", count: 5) # Header plus four rows
      expect(page.all("td.name a").map(&:text)).to eq(["All Hands", "Knitting Club",
                                                       "Meals Committee", "Fun Team (Inactive)"])

      select_lens_and_wait(:sort, "By Type")
      expect(page.all("td.name a").map(&:text)).to eq(["Knitting Club", "Meals Committee", "All Hands",
                                                       "Fun Team (Inactive)"])

      select2_lens_and_wait(:user, manager1.decorate.full_name, url_value: manager1.id)
      expect(page.all("td.name a").map(&:text)).to eq(["Knitting Club", "All Hands"])
    end

    scenario "create" do
      visit(groups_groups_path)
      click_link("Create Group")

      expect(page).not_to have_content("What communities this group is available")

      fill_in("Description", with: "Stuff")
      select("Squad", from: "Type")
      select("Closed", from: "Availability")

      click_link("Add Member")
      within(all(".nested-fields")[0]) do
        select2(user1.name, from: find("select.user_select"))
        select("Manager", from: "Kind")
      end

      click_link("Add Member")
      within(all(".nested-fields")[1]) do
        select2(user2.name, from: find("select.user_select"))
        select("Member", from: "Kind")
      end

      # Joiners should be hidden when changing to everybody.
      expect(page).to have_content(user2.name)
      expect(page).to have_content(user1.name)
      select("Everybody", from: "Availability")
      expect(page).not_to have_content(user2.name)
      expect(page).to have_content(user1.name)

      click_link("Add Member")
      within(all(".nested-fields")[1]) do
        select2(user2.name, from: find("select.user_select"))
        select("Opt Out", from: "Kind")
      end

      click_button("Save")
      expect(page).to have_alert(/problems below/)
      fill_in("Name", with: "Newgroup")
      click_button("Save")
      expect(page).to have_alert(/created successfully/)
    end

    scenario "deactivate/activate/delete" do
      visit(edit_groups_group_path(group1))
      accept_confirm { click_on("Deactivate") }
      expect_success

      click_link("Edit")
      click_link("reactivate it")
      expect_success

      expect(page).not_to have_content("#{group1.name} (Inactive)")
      click_link("Edit")
      accept_confirm { click_on("Delete") }
      expect_success

      expect(page).not_to have_content(group1.name)
    end
  end

  context "as cluster admin with two communities" do
    let(:actor) { create(:cluster_admin) }
    let!(:community2) { create(:community) }
    let!(:user3) { create(:user, community: community2) }

    scenario "edit" do
      visit(groups_groups_path)
      click_link(group1.name)
      click_link("Edit")

      expect(page).to have_content("What communities this group is available")

      # User in community 2 shouldn't be an option yet.
      within(all(".nested-fields")[0]) do
        expect { select2(user3.name, from: find("select.user_select")) }
          .to raise_error(Capybara::ElementNotFound)
      end

      check(community2.name)

      within(all(".nested-fields")[0]) do
        select2(user3.name, from: find("select.user_select"))
      end

      click_button("Save")
      click_link("Knitting Club")
      expect(page).to have_content("#{user3.name} (#{community2.abbrv})")
    end
  end

  context "as manager with two communities" do
    let(:actor) { manager1 }
    let!(:community2) { create(:community) }
    let!(:user3) { create(:user, community: community2) }

    before do
      group1.communities << community2
    end

    scenario "edit" do
      visit(groups_groups_path)
      click_link(group1.name)
      click_link("Edit")

      expect(page).not_to have_content("What communities this group is available")

      within(all(".nested-fields")[0]) do
        select2(user3.name, from: find("select.user_select"))
      end

      click_button("Save")
      click_link("Knitting Club")
      expect(page).to have_content("#{user3.name} (#{community2.abbrv})")
    end
  end

  context "as regular user" do
    let(:actor) { create(:user) }

    scenario "show, join, leave" do
      visit(groups_groups_path)
      click_link("Knitting Club")

      click_link("Join")
      expect(page).to have_alert(/successfully joined/)
      expect(page).to have_css(".user-list-member", text: actor.decorate.full_name)

      click_link("Leave")
      expect(page).to have_alert(/successfully left/)
      expect(page).not_to have_css(".user-list-member", text: actor.decorate.full_name)

      visit(groups_groups_path)
      click_link("All Hands")

      click_link("Opt-Out")
      expect(page).to have_alert(/successfully left/)
      expect(page).to have_css(".user-list-opt-out", text: actor.decorate.full_name)

      click_link("Re-Join")
      expect(page).to have_alert(/successfully joined/)
      expect(page).to have_css(".user-list-member", text: actor.decorate.full_name)
    end
  end
end
