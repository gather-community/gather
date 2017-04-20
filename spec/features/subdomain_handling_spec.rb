require "rails_helper"

feature "subdomain handling" do
  let(:apex) { Settings.url.host }
  let!(:community) { create(:community, slug: "foo") }
  let!(:community2) { create(:community, slug: "bar") }
  let(:user) { create(:user, community: community) }

  around do |example|
    stub_omniauth(google_oauth2: {email: user.google_email}) do
      example.run
    end
  end

  context "when not logged in" do
    scenario "visiting subdomain and logging in should redirect back to that subdomain" do
      with_subdomain("bar") do
        visit root_path
        expect(page).not_to have_content("Please log in to view that page")
        expect(current_url).to have_subdomain("bar")
        expect_valid_login_link_and_click
        expect(page).to have_content(user.name)
        expect(current_url).to have_subdomain("bar")
      end
    end

    scenario "visiting subdomain with path and logging in should return you to path after log in" do
      with_subdomain("bar") do
        visit meals_path
        expect(page).to have_content("Please log in to view that page")
        expect_valid_login_link_and_click
        expect(current_url).to have_subdomain_and_path("bar", "/meals")
      end
    end

    scenario "visiting invalid subdomain should 404" do
      with_subdomain("invalid") do
        visit root_path
        expect(page).to be_not_found
      end
    end

    scenario "visiting apex domain root and logging in should take you to community root" do
      visit root_path
      expect_valid_login_link_and_click
      expect(page).to have_content(user.name)
      expect(current_url).to have_subdomain_and_path("foo", "/")
    end
  end

  context "when logged in" do
    before do
      login_as(user, scope: :user)
    end

    context "with own subdomain" do
      # scenario "visiting root should work" do
      # end

      # scenario "visiting path should work" do
      # end
    end
    #
    # context "with other community subdomain" do
    #   scenario "visiting root should work if permitted" do
    #   end
    #
    #   scenario "visiting path should work if permitted" do
    #   end
    #
    #   scenario "visiting root should 403 if not permitted" do
    #   end
    #
    #   scenario "visiting path should 403 if not permitted" do
    #   end
    # end

    context "with apex domain" do
      scenario "visiting root should redirect to home community root" do
        visit root_path
        expect(current_url).to expect(current_url).to have_subdomain_and_path("foo", "/")
      end

      # scenario "visiting devise route should work" do
      # end
      #
      # scenario "visiting legacy collection route should redirect to home community route" do
      # end
      #
      # scenario "visiting non-legacy collection route should 404" do
      # end
      #
      # context "with original community object" do
      #   scenario "visiting legacy member route should redirect to appropriate community route" do
      #   end
      #
      #   scenario "visiting non-legacy member route should 404" do
      #   end
      # end
      #
      # context "with non-existant object" do
      #   scenario "visiting legacy member route should 404" do
      #
      #   end
      # end
      #
      # context "with non-original community object" do
      #   scenario "visiting legacy member route should 404" do
      #
      #   end
      # end
    end
  end
end
