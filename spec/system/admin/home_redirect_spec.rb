# frozen_string_literal: true

require "rails_helper"

describe "home redirect" do
  context "with community subdomain" do
    before do
      use_user_subdomain(actor)
      login_as(actor, scope: :user)
    end

    context "with admin" do
      let(:actor) { create(:admin) }

      scenario "admin changes default home and visits root url" do
        visit "/"
        expect(page).to have_title("Directory")

        ["Meals", "Directory", ["Calendars", "Events & Reservations"], "Wiki"].each do |new_default|
          new_default = Array.wrap(new_default)
          change_default_home(new_default[0])
          visit "/"
          expect(page).to have_title(new_default[-1])
        end
      end
    end

    context "with user" do
      let(:home_cmty) { create(:community) }
      let(:actor) { create(:user, community: home_cmty) }

      before do
        actor.community.settings.default_landing_page = default_landing_page
        actor.community.save!
      end

      context "with meals default home page set" do
        let(:default_landing_page) { "meals" }

        scenario "user visits root with meals default home page set" do
          visit "/"
          expect(page).to have_title("Meals")
        end
      end

      context "with directory default home page set" do
        let(:default_landing_page) { "directory" }

        scenario "user visits root with directory default home page set" do
          visit "/"
          expect(page).to have_title("Directory")
        end
      end

      context "with calendars default home page set" do
        let(:default_landing_page) { "calendars" }

        scenario "user visits root with calendars default home page set" do
          visit "/"
          expect(page).to have_title("Events & Reservations")
        end
      end

      context "with wiki default home page set" do
        let(:default_landing_page) { "wiki" }

        scenario "user visits root with wiki default home page set" do
          visit "/"
          expect(page).to have_title("Wiki")
        end
      end
    end

    def change_default_home(new_default)
      visit("/admin/settings/community")
      select(new_default, from: "Default Landing Page")
      click_button("Save")
      expect(page).to have_content("Settings updated successfully.")
    end
  end

  context "with apex domain" do
    before do
      login_as(actor, scope: :user)
    end

    context "with user" do
      let(:home_cmty) { create(:community) }
      let(:actor) { create(:user, community: home_cmty) }

      before do
        actor.community.settings.default_landing_page = default_landing_page
        actor.community.save!
      end

      context "with meals default home page set" do
        let(:default_landing_page) { "meals" }

        scenario "user visits root with meals default home page set" do
          visit "/"
          expect(page).to have_title("Meals")
          expect(current_url).to eq("http://#{home_cmty.slug}.gatherdev.org:31337/meals")
        end
      end

      context "with directory default home page set" do
        let(:default_landing_page) { "directory" }

        scenario "user visits root with directory default home page set" do
          visit "/"
          expect(page).to have_title("Directory")
          expect(current_url).to eq("http://#{home_cmty.slug}.gatherdev.org:31337/users")
        end
      end

      context "with calendars default home page set" do
        let(:default_landing_page) { "calendars" }

        scenario "user visits root with calendars default home page set" do
          visit "/"
          expect(page).to have_title("Events & Reservations")
          expect(current_url).to eq("http://#{home_cmty.slug}.gatherdev.org:31337/calendars/events")
        end
      end

      context "with wiki default home page set" do
        let(:default_landing_page) { "wiki" }

        scenario "user visits root with wiki default home page set" do
          visit "/"
          expect(page).to have_title("Wiki")

          # Wiki index redirects again to home.
          expect(current_url).to eq("http://#{home_cmty.slug}.gatherdev.org:31337/wiki/home")
        end
      end
    end
  end
end
