require "rails_helper"

feature "subdomain handling" do
  let(:apex) { Settings.url.host }
  let(:cluster) { create(:cluster) }
  let(:cluster2) { create(:cluster) }
  let!(:home_cmty) { create(:community, slug: "foo", cluster: cluster) }
  let!(:neighbor_cmty) { create(:community, slug: "bar", cluster: cluster) }
  let!(:outside_cmty) { create(:community, slug: "qux", cluster: cluster2) }
  let(:user) { create(:user, community: home_cmty) }

  around do |example|
    stub_omniauth(google_oauth2: {email: user.google_email}) do
      example.run
    end
  end

  context "when not signed in" do
    scenario "visiting subdomain and signing in should redirect back to that subdomain" do
      with_subdomain("bar") do
        visit root_path
        expect(page).not_to have_content("Please sign in to view that page")
        expect(current_url).to have_subdomain("bar")
        expect_valid_sign_in_link_and_click
        expect(page).to have_content(user.name)
        expect(current_url).to have_subdomain("bar")
      end
    end

    scenario "visiting subdomain with path and signing in should return you to path after sign in" do
      with_subdomain("bar") do
        visit meals_path
        expect(page).to have_content("Please sign in to view that page")
        expect_valid_sign_in_link_and_click
        expect(current_url).to have_subdomain_and_path("bar", "/meals")
      end
    end

    scenario "visiting invalid subdomain should 404" do
      with_subdomain("invalid") do
        visit root_path
        expect(page).to be_not_found
      end
    end

    scenario "visiting apex domain root and signing in should take you to community root" do
      visit "/"
      expect_valid_sign_in_link_and_click
      expect(page).to have_content(user.name)
      expect(current_url).to have_subdomain_and_path("foo", "/")
    end
  end

  context "when signed in" do
    before do
      login_as(user, scope: :user)
    end

    context "with own subdomain" do
      around { |ex| with_subdomain("foo") { ex.run } }

      scenario "visiting root should work" do
        visit "/"
        expect(current_url).to have_subdomain_and_path("foo", "/")
        expect(page).to be_signed_in_root
      end

      scenario "visiting path should work" do
        visit "/meals"
        expect(current_url).to have_subdomain_and_path("foo", "/meals")
        expect(page).to have_title("Meals")
      end

      scenario "signing out should redirect back to apex domain", js: true do
        visit "/meals"
        find(".personal-nav .dropdown-toggle").click
        find(".personal-nav .dropdown-menu a", text: "Sign Out").click
        expect(page).to have_content("You are now signed out")
        expect(current_url).to have_subdomain_and_path(nil, "/signed-out")
      end
    end

    context "with other community subdomain as normal user" do
      context "in cluster" do
        around { |ex| with_subdomain("bar") { ex.run } }

        scenario "visiting root should work" do
          visit "/"
          expect(current_url).to have_subdomain_and_path("bar", "/")
          expect(page).to have_title("Directory")
        end

        scenario "visiting path should work" do
          visit "/meals"
          expect(current_url).to have_subdomain_and_path("bar", "/meals")
          expect(page).to have_title("Meals")
        end
      end

      context "outside of cluster" do
        around { |ex| with_subdomain("qux") { ex.run } }

        scenario "visiting root should 403" do
          visit "/"
          expect(page).to be_forbidden
        end

        scenario "visiting path should 403" do
          visit "/meals"
          expect(page).to be_forbidden
        end
      end
    end

    context "with apex domain" do
      scenario "visiting root should redirect to home community root" do
        visit root_path
        expect(current_url).to have_subdomain_and_path("foo", "/")
      end

      scenario "visiting supported collection route should redirect to home community route" do
        visit "/meals"
        expect(current_url).to have_subdomain_and_path("foo", "/meals")
      end

      scenario "visiting unsupported collection route should 404" do
        visit "/users/invite"
        expect(page).to be_not_found
      end

      # User can see this meal but it's not hosted by home_cmty. So the redirected subdomain
      # should match neighbor_cmty.
      let(:meal) { create(:meal, host_community: neighbor_cmty, communities: [home_cmty, neighbor_cmty]) }

      scenario "visiting supported member route should redirect to appropriate community route" do
        visit "/meals/#{meal.id}"
        expect(current_url).to have_subdomain_and_path("bar", "/meals/#{meal.id}")
      end

      scenario "visiting unsupported member route should 404" do
        visit "/meals/#{meal.id}/edit"
        expect(page).to be_not_found
      end

      context "with non-existent object" do
        scenario "visiting unsupported member route should 404" do
          visit "/meals/2372944"
          expect(page).to be_not_found
        end
      end
    end
  end
end
