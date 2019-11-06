# frozen_string_literal: true

require "rails_helper"

describe "reservation calendar", js: true do
  let(:actor) { create(:user) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "with a meal event and a non-meal event" do
    let!(:resource1) { create(:resource, name: "Foo Room") }
    let!(:resource2) { create(:resource, name: "Bar Room") }
    let(:time) { Time.current.midnight + 9.hours }
    let(:time2) { (time + 2.weeks).at_beginning_of_month }
    let(:time2_ymd) { time2.strftime("%Y-%m-%d") }
    let(:time2_my) { time2.strftime("%B %Y") }
    let!(:meal) { create(:meal, :with_menu, title: "Yum", served_at: time + 9.hours, resources: [resource1]) }
    let!(:reservation) do
      create(:reservation, resource: resource1, starts_at: time, ends_at: time + 1.hour, name: "Funtimes")
    end

    before do
      meal.build_reservations
      meal.save!
    end

    scenario do
      # Clear saved calendar settings in localStorage
      visit("/")
      page.execute_script("localStorage.clear()")

      visit(reservations_path(resource_id: resource1.id))
      expect(page).to have_content("Yum")
      expect(page).to have_content("Funtimes")
      find(".fc-next-button").click
      find(".fc-next-button").click
      expect(page).not_to have_content("Funtimes")
      find(".fc-month-button").click

      # Test permalink and resource links update correctly.
      permalink_url = "/reservations?resource_id=#{resource1.id}&view=month&date=#{time2_ymd}"
      expect(page).to have_css(%(a#permalink[href="#{permalink_url}"]))
      other_resource_url = "/reservations?resource_id=#{resource2.id}&view=month&date=#{time2_ymd}"
      expect(page).to have_css(%(a.resource-link[href="#{other_resource_url}"]), text: "Bar Room")

      # Test params respected on page load.
      click_link("Bar Room")
      expect(page).to have_echoed_url(other_resource_url)
      expect(page).to have_css(".fc-month-button.fc-state-active")
      expect(page).to have_css(".fc-header-toolbar h2", text: time2_my)

      # Test storage of calendar params in localStorage
      visit(reservations_path(resource_id: resource2.id))
      expect(page).to have_css(".fc-month-button.fc-state-active")
      expect(page).to have_css(".fc-header-toolbar h2", text: time2_my)
    end
  end
end
