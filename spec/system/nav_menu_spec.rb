# frozen_string_literal: true

require "rails_helper"

describe "nav menu" do
  let!(:community) { create(:community, slug: "foo") }
  let!(:community2) { create(:community, slug: "bar") }
  let(:actor) { create(:user, community: community) }
  let(:setting) { nil }

  before do
    community.settings.main_nav_customizations = setting
    community.save!
    login_as(actor, scope: :user)
  end

  context "when visiting page on subdomain" do
    before do
      use_user_subdomain(actor)
    end

    context "basic" do
      scenario "no customizations" do
        main_nav_test(match:
          [
            ["People", "http://foo.gatherdev.org:31337/users"],
            ["Groups", "http://foo.gatherdev.org:31337/groups"],
            ["Meals", "http://foo.gatherdev.org:31337/meals"],
            ["Work", "http://foo.gatherdev.org:31337/work/signups"],
            ["Calendars", "http://foo.gatherdev.org:31337/calendars/events"],
            ["Wiki", "http://foo.gatherdev.org:31337/wiki"]
          ])
      end
    end

    context "changes" do
      let(:setting) { "[Calendars]()[Wiki](http://wikipedia.org) [Google](http://google.com)" }

      scenario "change one link, disable one, add another" do
        main_nav_test(match:
          [
            ["People", "http://foo.gatherdev.org:31337/users"],
            ["Groups", "http://foo.gatherdev.org:31337/groups"],
            ["Meals", "http://foo.gatherdev.org:31337/meals"],
            ["Work", "http://foo.gatherdev.org:31337/work/signups"],
            ["Wiki", "http://wikipedia.org"],
            ["Google", "http://google.com"]
          ])
      end
    end
  end

  context "when visiting page on other community subdomain" do
    before do
      use_subdomain("bar")
    end

    scenario "keeps same subdomain" do
      visit("/users")
      expect(find(".main-nav ul.nav li a", text: "People")["href"]).to eq("http://bar.gatherdev.org:31337/users")
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
