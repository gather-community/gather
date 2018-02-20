require "rails_helper"

feature "user index" do
  let(:user) { create(:user) }
  let(:admin) { create(:admin) }
  let(:inactive) { create(:user, :inactive, first_name: "Longgone") }

  around { |ex| with_user_home_subdomain(user) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  context "as user" do
    let(:actor) { user }

    scenario "download csv" do
      users = create_list(:user, 4)
      Timecop.freeze("2017-04-15 12:00pm") do
        visit "/users"
        expect(page).to have_css("a", text: "Download as CSV")
        click_on("Download as CSV")
        filename = "#{user.community.slug}-directory-2017-04-15.csv"
        expect(page.response_headers["Content-Disposition"]).to eq %Q{attachment; filename="#{filename}"}
        expect(page).to have_content(/#{users[0].first_name}/)
      end
    end

    scenario "table view", js: true do
      inactive.save!
      visit "/users"
      select_lens(:view, "Table")
      expect(page).to have_css("table.index tr td", text: user.name)
      expect(page).not_to have_content("Longgone")
    end

    scenario "printing album view", js: true do
      visit "/users"
      expect(page).not_to have_css("#printable-directory-album table", visible: false)
      click_print_button
      # Should load the full directory, but hidden.
      expect(page).to have_css("#printable-directory-album table", visible: false)
    end
  end

  context "as admin" do
    let(:actor) { admin }

    scenario "table with inactive view", js: true do
      inactive.save!
      visit "/users"
      select_lens(:view, "Table w/ Inactive")
      expect(page).to have_css("table.index tr td", text: user.name)
      expect(page).to have_content("Longgone")
    end
  end
end
