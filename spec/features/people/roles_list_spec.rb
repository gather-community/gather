# frozen_string_literal: true
require "rails_helper"

feature "roles index" do
  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  context "as user" do
    let(:actor) { create(:user) }

    scenario "visit roles list page" do
      coordinators = create_list(:work_coordinator, 4)
      admins = create_list(:admin, 4)

      visit "/roles"
      expect(page).to have_css("h3", text: "Work Coordinator")
      expect(page).to have_css("h3", text: "Admin")
      coordinators.each do |user|
        expect(page).to have_css("a", text: user.name)
      end

      admins.each do |user|
        expect(page).to have_css("a", text: user.name)
      end
    end
  end
end
