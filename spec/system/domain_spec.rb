# frozen_string_literal: true

require "rails_helper"

describe "domains", js: true do

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "multi community" do
    let(:community1) { Defaults.community }
    let(:community2) { create(:community, name: "Zorp") }
    let!(:domain1) { create(:domain, name: "domain1.com", communities: [community1]) }
    let!(:domain2) { create(:domain, name: "domain2.com", communities: [community2]) }
    let!(:domain3) { create(:domain, name: "domain3.com", communities: [community1, community2]) }
    let!(:domain4) { create(:domain, name: "domain4.com", communities: [community1]) }
    let!(:list1) { create(:group_mailman_list, domain: domain1) }

    context "as admin" do
      let(:actor) { create(:admin) }

      scenario "index" do
        visit(domains_path)
        expect(page).to have_title("Domains")
        expect(page).to have_css("table.index tr", count: 4) # Header plus 3 rows
        expect(page.all("td.name a").map(&:text)).to eq(["domain1.com", "domain3.com", "domain4.com"])
        expect(page.all("td.communities").map(&:text)).to eq(["Default", "Default, Zorp", "Default"])
      end

      scenario "show" do
        visit(domain_path(domain1))
        expect(page).to have_title(domain1.name)
        expect(page).to have_content(domain1.name)
        expect(page).to have_content(domain1.communities.map(&:name).join(", "))
        expect(page).to have_content(domain1.group_mailman_lists[0].name)
      end

      scenario "create" do
        visit(domains_path)
        click_link("Add Domain", match: :first)

        expect(page).not_to have_content("What communities this domain is available")

        fill_in("Name", with: "nerp")

        click_button("Save")
        expect(page).to have_alert(/problems below/)
        fill_in("Name", with: "nerp.com")
        click_button("Save")
        expect(page).to have_alert(/created successfully/)
      end

      scenario "delete" do
        visit(domain_path(domain4))
        accept_confirm { click_on("Delete") }
        expect_success

        expect(page).not_to have_content(domain4.name)
      end
    end

    context "as cluster admin with two communities" do
      let(:actor) { create(:cluster_admin) }

      scenario "create" do
        visit(new_domain_path)

        expect(page).to have_content("What communities this domain is available")

        fill_in("Name", with: "nerp.com")
        check(community2.name)

        click_button("Save")
        expect(page).to have_alert(/created successfully/)
        expect(page).to have_content("nerp.com")
        expect(page).to have_content(community2.name)
      end
    end
  end

  context "single community" do
    let(:community) { Defaults.community }
    let!(:domain) { create(:domain, name: "domain.com", communities: [community]) }
    let!(:list) { create(:group_mailman_list, domain: domain) }
    let(:actor) { create(:admin) }

    scenario "index" do
      visit(domains_path)
      expect(page).to have_title("Domains")
      expect(page).to have_css("table.index tr", count: 2) # Header plus 1 row
      expect(page.all("td.name a").map(&:text)).to eq([domain.name])
      expect(page).not_to have_content("Communities")
    end

    scenario "show" do
      visit(domain_path(domain))
      expect(page).to have_title(domain.name)
      expect(page).to have_content(domain.name)
      expect(page).not_to have_content("Communities")
      expect(page).to have_content(domain.group_mailman_lists[0].name)
    end

    scenario "create" do
      visit(domains_path)
      click_link("Add Domain", match: :first)

      expect(page).not_to have_content("What communities this domain is available")

      fill_in("Name", with: "nerp.com")

      click_button("Save")
      expect(page).to have_alert(/created successfully/)
    end
  end
end
