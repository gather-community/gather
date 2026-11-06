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
    visit(admin_communities_path)
    expect(page).to have_content("Default")
    expect(page).to have_content("Other Community")
    expect(page).not_to have_content("View Signups")

    within(".stats-sidebar") do
      expect(page).to have_content("Stats")
      expect(find("tr", text: "Trial")).to have_content("2")
      expect(find("tr", text: "Subscribed")).to have_content("0")
      expect(page).to have_content("Years Active: #{Time.zone.today.year - 2014}")
    end

    within("#local-footer") { expect(page).to have_button("Resync subscriptions") }
    within("#global-footer") do
      expect(page).to have_link("Privacy Policy")
      expect(page).to have_link("Credits")
      expect(page).to have_link("Return to Main Site")
      expect(page).not_to have_link("Admin")
      expect(page).not_to have_button("Resync subscriptions")
    end
  end

  scenario "admin nav and header" do
    visit(admin_communities_path)
    within(".main-nav") do
      expect(page).to have_link("Communities", href: admin_communities_path)
      expect(page).to have_link("Domains", href: admin_domains_path)
      expect(page).to have_link("Flags", href: admin_feature_flags_path)
    end
    within("nav.subnav") do
      expect(page).to have_css("li.active", text: "Communities")
      click_link("Signups")
    end
    expect(page).to have_title("Community Signup Applications")
    within("nav.subnav") { expect(page).to have_css("li.active", text: "Signups") }

    within(".personal-nav .dropdown-menu") do
      expect(page).to have_css("li", count: 1)
      expect(page).to have_link("Sign Out")
    end

    within(".logo.nav-1") do
      expect(page).to have_content("Admin")
      find("a").click
    end
    expect(page).to have_current_path(admin_communities_path)
  end

  scenario "main site footer links to the admin pages" do
    visit(users_path)
    within("#global-footer") do
      expect(page).not_to have_link("Communities")
      expect(page).not_to have_link("Domains")
      click_link("Admin")
    end
    expect(page).to have_current_path(admin_communities_path)
  end

  scenario "pagination" do
    create_list(:community, 20)
    visit(admin_communities_path)
    expect(page).to have_css("table tbody tr", count: 20)
    within(".pagination") { click_link("2") }
    expect(page).to have_css("table tbody tr", count: 2)
  end

  scenario "status lens", js: true do
    communityB.update!(deactivated_at: Time.current)

    visit(admin_communities_path)
    expect(page).to have_content("Default")
    expect(page).to have_content("Other Community")

    select_lens(:status, "Deactivated")
    expect(page).not_to have_link("Default")  # cluster is also named "Default"; check link not text
    expect(page).to have_content("Other Community")

    select_lens(:status, "Trial")
    expect(page).to have_content("Default")
    expect(page).not_to have_content("Other Community")

    select_lens(:status, "All Statuses")
    expect(page).to have_content("Default")
    expect(page).to have_content("Other Community")
  end
end
