require "rails_helper"

feature "subdomain handling" do
  let(:apex) { Settings.url.host }
  let(:cluster) { create(:cluster) }
  let(:cluster2) { create(:cluster) }
  let!(:community) { create(:community, slug: "foo", cluster: cluster) }
  let!(:community2) { create(:community, slug: "bar", cluster: cluster) }
  let!(:community3) { create(:community, slug: "qux", cluster: cluster2) }
  let(:user) { create(:user, community: community) }
  let(:root_title) { "Directory" }

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
      visit "/"
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
      around { |ex| with_subdomain("foo") { ex.run } }

      scenario "visiting root should work" do
        visit "/"
        expect(current_url).to have_subdomain_and_path("foo", "/")
        expect(page).to have_title(root_title)
      end

      scenario "visiting path should work" do
        visit "/meals"
        expect(current_url).to have_subdomain_and_path("foo", "/meals")
        expect(page).to have_title("Meals")
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
          expect(page).to have_content("You are not permitted")
        end

        scenario "visiting path should 403" do
          visit "/meals"
          expect(page).to have_content("You are not permitted")
        end
      end
    end

    context "with apex domain" do
      scenario "visiting root should redirect to home community root" do
        visit root_path
        expect(current_url).to have_subdomain_and_path("foo", "/")
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
