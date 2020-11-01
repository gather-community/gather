# frozen_string_literal: true

require "rails_helper"

describe "nav menu" do
  let(:community) { create(:community) }
  let(:actor) { create(:user, community: community) }

  before do
    use_user_subdomain(actor)
    community.settings.main_nav_customizations = setting
    community.save!
    login_as(actor, scope: :user)
  end

  context "basic" do
    let(:setting) { "" }

    scenario "no customizations" do
      main_nav_test(match: [["People", "/users"],
                            ["Groups", "/groups"],
                            ["Meals", "/meals"],
                            ["Work", "/work/signups"],
                            ["Reservations", "/reservations"],
                            ["Wiki", "/wiki"]])
    end
  end
  context "changes" do
    let(:setting) { "[Reservations]()[Wiki](http://wikipedia.org) [Google](http://google.com)" }

    scenario "change one link, disable one, add another" do
      main_nav_test(match: [["People", "/users"],
                            ["Groups", "/groups"],
                            ["Meals", "/meals"],
                            ["Work", "/work/signups"],
                            ["Wiki", "http://wikipedia.org"],
                            ["Google", "http://google.com"]])
    end
  end

  def main_nav_test(match: [])
    # go to a page that will have the main nav menu on it
    visit("/users")
    # Get all of the links in the main nav menu
    # map them into an array of arrays
    # and compare them with what they are supposed to be
    expect(all(".main-nav ul.nav li a").map { |e| [e.text, e["href"]] }).to eql(match)
  end
end
