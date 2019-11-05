# frozen_string_literal: true

require "rails_helper"

describe "subdomain handling" do
  let(:apex) { Settings.url.host }
  let(:cluster) { Defaults.cluster }
  let(:cluster2) { create(:cluster) }
  let!(:home_cmty) { create(:community, slug: "foo") }
  let!(:neighbor_cmty) { create(:community, slug: "bar") }
  let!(:outside_cmty) { with_tenant(cluster2) { create(:community, slug: "qux") } }
  let(:user) { create(:user, community: home_cmty) }

  around do |example|
    stub_omniauth(google_oauth2: {email: user.google_email}) do
      example.run
    end
  end

  context "when not signed in" do
    scenario "visiting root on subdomain and signing in with google should redirect to apex and back" do
      with_subdomain("foo") do
        visit(root_path) # This will go to root with subomain, but should redirect to apex.
        expect(page).not_to have_content("Please sign in to view that page")
        expect(current_url).to have_apex_domain
        expect_sign_in_with_google_link_and_click
        expect(page).to have_content(user.name)
        expect(current_url).to have_subdomain("foo")
      end
    end

    scenario "visiting subdomain with path and signing in should return you to path after sign in" do
      # Note that this is not the user's home subdomain, but we respect it anyway after sign in.
      with_subdomain("bar") do
        visit(meals_path) # This will go to meals page with subomain, but should redirect to apex.
        expect(page).to have_content("Please sign in to view that page")
        expect(current_url).to have_apex_domain
        expect_sign_in_with_google_link_and_click
        expect(current_url).to have_subdomain_and_path("bar", "/meals")
      end
    end

    scenario "visiting invalid subdomain should 404" do
      with_subdomain("invalid") do
        visit(root_path)
        expect(page).to be_not_found
      end
    end

    scenario "visiting apex domain root and signing in should take you to community root" do
      visit("/")
      expect_sign_in_with_google_link_and_click
      expect(page).to have_content(user.name)
      expect(current_url).to have_subdomain_and_path("foo", "/users")
    end
  end

  context "when signed in" do
    before do
      login_as(user, scope: :user)
    end

    context "with own subdomain" do
      around { |ex| with_subdomain("foo") { ex.run } }

      scenario "visiting root should work" do
        visit("/")
        expect(current_url).to have_subdomain_and_path("foo", "/users")
        expect(page).to be_signed_in_root
      end

      scenario "visiting path should work" do
        visit("/meals")
        expect(current_url).to have_subdomain_and_path("foo", "/meals")
        expect(page).to have_title("Meals")
      end

      scenario "signing out should redirect back to apex domain", js: true do
        visit("/meals")
        click_on_personal_nav("Sign Out")
        expect(page).to have_content("You are now signed out")
        expect(current_url).to have_subdomain_and_path(nil, "/people/users/signed-out")
      end
    end

    context "with other community subdomain as normal user" do
      context "in cluster" do
        around { |ex| with_subdomain("bar") { ex.run } }

        scenario "visiting root should work" do
          visit("/")
          expect(current_url).to have_subdomain_and_path("bar", "/users")
          expect(page).to have_title("Directory")
        end

        scenario "visiting path should work" do
          visit("/meals")
          expect(current_url).to have_subdomain_and_path("bar", "/meals")
          expect(page).to have_title("Meals")
        end
      end

      context "outside of cluster" do
        around { |ex| with_subdomain("qux") { ex.run } }

        scenario "visiting root should 403" do
          visit("/")
          expect(page).to be_forbidden
        end

        scenario "visiting path should 403" do
          visit("/meals")
          expect(page).to be_forbidden
        end
      end
    end

    context "with apex domain" do
      scenario "visiting root should redirect to home community root" do
        visit("/")
        expect(current_url).to have_subdomain_and_path("foo", "/users")
      end

      scenario "visiting URL with query string should also redirect" do
        visit("/meals?bar=123")
        expect(current_url).to have_subdomain_and_path("foo", "/meals?bar=123")
      end

      scenario "visiting supported collection route should redirect to home community route" do
        visit("/meals")
        expect(current_url).to have_subdomain_and_path("foo", "/meals")
      end

      scenario "visiting unsupported collection route should 404" do
        visit("/users/invite")
        expect(page).to be_not_found
      end

      # User can see this meal but it's not hosted by home_cmty. So the redirected subdomain
      # should match neighbor_cmty.
      let(:meal) { create(:meal, community: neighbor_cmty, communities: [home_cmty, neighbor_cmty]) }

      scenario "visiting supported member route should redirect to appropriate community route" do
        visit("/meals/#{meal.id}")
        expect(current_url).to have_subdomain_and_path("bar", "/meals/#{meal.id}")
      end

      scenario "visiting unsupported member route should 404" do
        visit("/meals/#{meal.id}/edit")
        expect(page).to be_not_found
      end

      context "with non-existent object" do
        scenario "visiting unsupported member route should 404" do
          visit("/meals/2372944")
          expect(page).to be_not_found
        end
      end
    end
  end
end
