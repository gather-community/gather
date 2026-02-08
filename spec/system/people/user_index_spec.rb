# frozen_string_literal: true

require "rails_helper"

describe "user index", js: true do
  let!(:user) { create(:user, first_name: "John") }
  let!(:admin) { create(:admin) }
  let!(:user2) { create(:user, first_name: "Ruddiger") }
  let!(:user3) { create(:user, first_name: "Aloysius") }
  let!(:user4) { create(:user, :child, first_name: "Tiny") }
  let(:inactive) { create(:user, :inactive, first_name: "Longgone") }
  let!(:community2) { create(:community) }

  before do
    use_user_subdomain(user)
    login_as(actor, scope: :user)

    user2.household.update!(unit_num: "1")
    user3.household.update!(unit_num: "5")
  end

  context "as user" do
    let(:actor) { user }

    scenario "download csv" do
      Timecop.freeze("2017-04-15 12:00pm") do
        visit(users_path)
        click_link("Download as CSV")
        downloads = wait_for_downloads
        expect(downloads.size).to eq(1)
        expect(File.read(downloads.first)).to match(/"ID",First Name,Last Name/)
        expect(File.basename(downloads.first)).to eq("#{user.community.slug}-directory-2017-04-15.csv")
      end
    end

    scenario "album view" do
      inactive.save!
      visit("/users")
      select_lens(:view, "Album")
      expect(page).to have_content(user.name)
      expect(page).not_to have_content("Longgone")
    end

    scenario "table view" do
      inactive.save!
      visit(users_path)
      select_lens(:view, "Table")
      expect(page).to have_css("table.index tr td", text: user.name)
      expect(page).not_to have_content("Longgone")
    end

    scenario "printing album view" do
      visit(users_path)
      expect(page).not_to have_css("#printable-directory-album table", visible: false)
      click_print_button
      # Should load the full directory, but hidden.
      expect(page).to have_css("#printable-directory-album table", visible: false)
    end

    scenario "community lens" do
      visit(users_path)
      expect(page).to have_echoed_url(%r{https?://#{Defaults.community.subdomain}\.})
      select_lens(:community, community2.name)
      expect(page).to have_echoed_url(%r{https?://#{community2.subdomain}\.})
    end

    scenario "search" do
      visit(users_path)
      expect(page).to have_content("Ruddiger")
      expect(page).to have_content("Aloysius")
      fill_in_lens(:search, "Aloysius")
      expect(page).not_to have_content("Ruddiger")
      expect(page).to have_content("Aloysius")
    end

    scenario "life stage lens" do
      visit(users_path)
      expect(page).to have_content("Ruddiger")
      expect(page).to have_content("Tiny")
      select_lens(:lifestage, "Adults")
      expect(page).not_to have_content("Tiny")
      expect(page).to have_content("Ruddiger")
      select_lens(:lifestage, "Children")
      expect(page).not_to have_content("Ruddiger")
      expect(page).to have_content("Tiny")
      select_lens(:lifestage, "Adults + Children")
      expect(page).to have_content("Ruddiger")
      expect(page).to have_content("Tiny")
    end

    scenario "sort lens" do
      visit(users_path)
      expect(page).to have_content(/Aloysius.+Ruddiger/m)
      select_lens(:sort, "By Unit")
      expect(page).to have_content(/Ruddiger.+Aloysius/m)
      select_lens(:sort, "By Name")
      expect(page).to have_content(/Aloysius.+Ruddiger/m)
    end
  end

  context "as admin" do
    let(:actor) { admin }

    scenario "table with inactive view" do
      inactive.save!
      visit(users_path)
      select_lens(:view, "Table w/ Inactive")
      expect(page).to have_css("table.index tr td", text: user.name)
      expect(page).to have_content("Longgone")
    end
  end
end
