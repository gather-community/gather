# frozen_string_literal: true

require "rails_helper"

feature "nav menu" do
  let(:actor) { create(:admin) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  context "basic" do
    scenario "index" do
      # no customizations
      main_nav_test(setting: "",
                    have: {"People" => "/users",
                           "Meals" => "/meals",
                           "Work" => "/work/signups",
                           "Reservations" => "/reservations",
                           "Wiki" => "/wiki"},
                    not_have: [])
      # change one link and add another
      main_nav_test(setting: "[wiki](http://wikipedia.org) [google](http://google.com)",
                    have: {"People" => "/users",
                           "Meals" => "/meals",
                           "Work" => "/work/signups",
                           "Reservations" => "/reservations",
                           "Wiki" => "http://wikipedia.org",
                           "Google" => "http://google.com"},
                    not_have: [])
      # add two links
      main_nav_test(setting: "[Yahoo](http://yahoo.com) [google](http://google.com)",
                    have: {"People" => "/users",
                           "Meals" => "/meals",
                           "Work" => "/work/signups",
                           "Reservations" => "/reservations",
                           "Wiki" => "/wiki",
                           "Yahoo" => "http://yahoo.com",
                           "Google" => "http://google.com"},
                    not_have: [])
      # disable one link
      main_nav_test(setting: "[wiki](none)",
                    have: {"People" => "/users",
                           "Meals" => "/meals",
                           "Work" => "/work/signups",
                           "Reservations" => "/reservations"},
                    not_have: ["wiki"])
      # no valid data 
      main_nav_test(setting: "irrelevant gobbledygook",
                    have: {"People" => "/users",
                           "Meals" => "/meals",
                           "Work" => "/work/signups",
                           "Reservations" => "/reservations",
                           "Wiki" => "/wiki"},
                    not_have: [])
      # complicated url
      main_nav_test(setting: "[Somewhere out there](http://groucho:swordfish@somewhere.com?foo=bar&baz=frobozz+and+more%21)",
                    have: {"People" => "/users",
                           "Meals" => "/meals",
                           "Work" => "/work/signups",
                           "Reservations" => "/reservations",
                           "Wiki" => "/wiki",
                           "Somewhere out there" => "http://groucho:swordfish@somewhere.com?foo=bar&baz=frobozz+and+more%21"},
                    not_have: [])
    end
  end

  def main_nav_test(setting: "", have: {}, not_have: [])
    visit("/admin/settings/community")
    fill_in("Top Menu Customizations", with: setting)
    click_button("Save")
    have.each { |txt, linkto| expect(page).to have_link(txt, href: linkto) }
    not_have.each { |txt| expect(page).not_to have_selector("td.main-nav ul.nav li", text: txt) }
  end
end
