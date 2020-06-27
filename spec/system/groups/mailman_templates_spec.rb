# frozen_string_literal: true

require "rails_helper"

describe "mailman templates" do
  # Not using any subdomain or authentication.

  context "matching list" do
    let!(:list) { create(:group_mailman_list, remote_id: "foo.example.com") }

    scenario do
      visit("/groups/mailman/templates/list:member:regular:footer/foo.example.com/en")
      expect(page).to have_content("To unsubscribe, visit the Group page and leave or opt-out.")
      expect(page).to have_content("http://gather.localhost.tv:31337/groups/#{list.group_id}")
    end
  end

  context "no matching list" do
    scenario do
      visit("/groups/mailman/templates/list:member:regular:footer/foo.example.com/en")
      expect(page).to have_content("To unsubscribe, visit the Group page and leave or opt-out.")
      expect(page).not_to have_content("http://")
    end
  end
end
