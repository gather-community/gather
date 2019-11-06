# frozen_string_literal: true

require "rails_helper"

describe "reservation form" do
  let(:user) { create(:user) }

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  context "with pre_notice" do
    let(:resource) { create(:resource) }
    let!(:protocol) { create(:reservation_protocol, resources: [resource], pre_notice: "May be bed bugs!") }

    scenario "should show warning" do
      visit new_reservation_path(resource_id: resource.id)
      expect(page).to have_content("May be bed bugs!")
    end
  end
end
