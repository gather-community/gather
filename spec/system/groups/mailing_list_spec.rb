# frozen_string_literal: true

require "rails_helper"

describe "mailing lists", js: true do
  let!(:group) { create(:group, name: "Knitting Club", availability: "open", kind: "club") }
  let(:actor) { create(:admin) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "with no domains" do
    scenario "show, edit list" do
      visit(groups_group_path(group))
      expect(page).to have_content("This group has no attached email list")
      click_link("Edit")
      expect(page).to have_content("You can't create an email list because there are no domains")
    end
  end

  context "with domains" do
    let!(:domain) { create(:domain, name: "fluff.com") }

    scenario "create, show, delete list" do
      visit(groups_group_path(group))
      click_link("Edit")

      # Create the list
      fill_in("groups_group_mailman_list_attributes_name", with: "knitting")
      expect(page).to have_content("List members are synchronized")
      click_button("Save")

      # Open the group page again
      click_link("Knitting Club")
      expect(page).to have_content("knitting@fluff.com")

      # Trigger a re-sync
      click_link("Sync Now")
      expect(page).to have_content("List sync started")

      # Delete the list
      click_link("Edit")
      check("Delete this list?")
      accept_alert { click_button("Save") }

      # Open page again to verify list is gone
      click_link("Knitting Club")
      expect(page).to have_content("This group has no attached email list")
    end

    context "with few add'l members/senders" do
      let!(:list) do
        create(:group_mailman_list, group: group, domain: domain, name: "knitting",
                                    additional_members: ["a@a.com", "b@b.com"], additional_senders: ["c@c.com", "d@d.com"])
      end

      scenario "shows all add'l members/senders" do
        visit(groups_group_path(group))
        expect(page).to have_content("knitting@fluff.com")
        expect(page).to have_content(/a@a\.com.*b@b\.com.*These addresses are also members/m)
        expect(page).to have_content(/c@c\.com.*d@d\.com.*These additional senders/m)
      end
    end

    context "with many add'l senders" do
      let(:addl_senders) { 15.times.map { |i| "#{i}@a.com" } }
      let!(:list) do
        create(:group_mailman_list, group: group, domain: domain, name: "knitting",
                                    additional_members: ["a@a.com", "b@b.com"], additional_senders: addl_senders)
      end

      scenario "shows subset of senders" do
        visit(groups_group_path(group))
        expect(page).to have_content("knitting@fluff.com")
        expect(page).to have_content(/a@a\.com.*b@b\.com.*These addresses are also members/m)
        expect(page).to have_content(/0@a\.com.*1@a\.com.*Show 5 more.*These additional senders/m)
        expect(page).not_to have_content(/10@a\.com/m)
      end
    end
  end
end
