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
    let(:api_response) do
      {
        entries: [
          {email: "a@a.com", role: "nonmember", moderation_action: "hold", display_name: "A Tuzz"},
          {email: "b@b.com", role: "nonmember", moderation_action: "accept", display_name: "Bo Fuzz"}
        ]
      }
    end

    scenario "show, edit, delete list" do
      with_env("STUB_MAILMAN" => api_response.to_json) do
        visit(groups_group_path(group))
        click_link("Edit")
        fill_in("groups_group_mailman_list_attributes_name", with: "knitting")
        expect(page).to have_content("List members are synchronized")
        click_button("Save")

        click_link("Knitting Club")
        expect(page).to have_content("knitting@fluff.com")
        expect(page).to have_content(/These additional senders.*A Tuzz\*\nBo Fuzz\n/m)
        click_link("Edit")

        check("Delete this list?")
        accept_alert { click_button("Save") }
        click_link("Knitting Club")
        expect(page).to have_content("This group has no attached email list")
      end
    end
  end
end
