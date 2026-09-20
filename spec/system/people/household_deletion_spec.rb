# frozen_string_literal: true

require "rails_helper"

describe "household deletion", js: true do
  let(:actor) { create(:admin) }
  let!(:household) { create(:household, name: "Doomed House", member_count: 0) }
  let!(:member) { create(:user, household: household, first_name: "House", last_name: "Member") }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "admin permanently deletes a household and its members after typed confirmation" do
    visit(edit_household_path(household))

    click_link("Delete Permanently")
    expect_modal
    fill_in_modal("Doomed House")
    click_modal_button

    expect(page).to have_css("div.alert-success", text: /permanently deleted/)
    expect(Household.exists?(household.id)).to be(false)
    expect(User.exists?(member.id)).to be(false)
  end

  scenario "refuses when the household has an unsettled balance" do
    account = household.accounts.first || create(:account, :no_activity, household: household)
    account.update!(total_new_charges: 50)
    visit(edit_household_path(household))

    click_link("Delete Permanently")
    fill_in_modal("Doomed House")
    click_modal_button

    expect(page).to have_css("div.alert-warning", text: /unsettled account balance/)
    expect(Household.exists?(household.id)).to be(true)
  end
end
