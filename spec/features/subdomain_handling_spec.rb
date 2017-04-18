require "rails_helper"

feature "subdomain handling" do
  let(:apex) { Settings.url.host }
  let!(:community) { create(:community, slug: "foo") }
  let!(:user) { create(:user) }

  around do |example|
    stub_omniauth(google_oauth2: {email: user.google_email}) do
      example.run
    end
  end

  context "when not logged in" do
    scenario "visiting subdomain and logging in should redirect back to that subdomain" do
      with_subdomain("foo") do
        visit root_path
        expect(page).not_to have_content("Please log in to view that page")
        expect(current_url).to have_subdomain("foo")
        expect_valid_login_link_and_click
        expect(page).to have_content(user.name)
        expect(current_url).to have_subdomain("foo")
      end
    end

    scenario "visiting subdomain with path and logging in should return you to path after log in" do
      with_subdomain("foo") do
        visit meals_path
        expect(page).to have_content("Please log in to view that page")
        expect_valid_login_link_and_click
        expect(current_url).to have_subdomain("foo")
        expect(current_url).to match(%r{/meals\z})
      end
    end

    scenario "visiting invalid subdomain should 404" do
      with_subdomain("invalid") do
        visit root_path
        expect(page).to be_not_found
      end
    end

    scenario "visiting valid but unpermitted subdomain and logging in" do
      # login should work but should get 403 once logged in
    end


    scenario "visiting other community subdomain root and logging in" do
      # should redirect you back to the other community root (directory) if you have access
    end

    scenario "visiting other community subdomain meals path and logging in" do
      # should redirect you back to the appropriate meals page if you have access
    end

    scenario "visiting apex domain and logging in" do
      # should take you to home page under your community subdomain
    end

    scenario "visiting apex domain meals path and logging in" do
      # should take you to home page under your community subdomain
    end
  end
end
