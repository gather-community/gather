require "rails_helper"

feature "roles index" do
  let(:user) { create(:user) }

  around { |ex| with_user_home_subdomain(user) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  context "as user" do
    let(:actor) { user }

    scenario "visit roles list page" do
      users = create_list(:user, 4)
      visit "/roles"
      #expect(page).to have_css("a", text: "Download as CSV")
      #expect(page).to have_css("table.index tr td", text: user.name)
      #click_on("Download as CSV")
    end
  end
end
