# frozen_string_literal: true

require "rails_helper"

feature "reservation calendar", js: true do
  let(:actor) { create(:user) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  context "with a meal event and a non-meal event" do
    let(:resource) { create(:resource) }
    let(:time) { Time.current.midnight + 9.hours }
    let!(:meal) { create(:meal, :with_menu, title: "Yum", served_at: time + 9.hours, resources: [resource]) }
    let!(:reservation) do
      create(:reservation, resource: resource, starts_at: time, ends_at: time + 1.hour, name: "Funtimes")
    end

    before do
      meal.build_reservations
      meal.save!
    end

    scenario "should show two events" do
      visit(reservations_path(resource_id: resource.id))
      expect(page).to have_content("Yum")
      expect(page).to have_content("Funtimes")
    end
  end
end
