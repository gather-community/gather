# frozen_string_literal: true

require "rails_helper"

describe "user deletion", js: true do
  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "as admin deleting another user" do
    let(:actor) { create(:admin) }
    let!(:target) { create(:user, first_name: "Delete", last_name: "Meplease") }

    scenario "permanently deletes after typed confirmation" do
      create(:meal, creator: target)
      visit(edit_user_path(target))

      click_link("Delete Permanently")
      expect_modal
      fill_in_modal("Delete Meplease")
      click_modal_button

      expect(page).to have_css("div.alert-success", text: /permanently deleted/)
      expect(User.exists?(target.id)).to be(false)
      # Directory no longer lists them.
      expect(page).to have_no_content("Delete Meplease")
    end

    scenario "refuses with a notice when a blocker applies" do
      account = target.household.accounts.first || create(:account, :no_activity, household: target.household)
      account.update!(total_new_charges: 50)
      visit(edit_user_path(target))

      click_link("Delete Permanently")
      fill_in_modal("Delete Meplease")
      click_modal_button

      expect(page).to have_css("div.alert-warning", text: /unsettled account balance/)
      expect(User.exists?(target.id)).to be(true)
    end

    scenario "refuses when the confirmation text does not match" do
      visit(edit_user_path(target))

      click_link("Delete Permanently")
      fill_in_modal("wrong name")
      click_modal_button

      expect(page).to have_css("div.alert-warning", text: /didn't match/)
      expect(User.exists?(target.id)).to be(true)
    end
  end

  context "as a regular user deleting their own account" do
    let(:actor) { create(:user, first_name: "Solo", last_name: "Departer") }

    scenario "signs out after deleting" do
      visit(edit_user_path(actor))

      click_link("Delete My Account")
      expect_modal
      fill_in_modal("Solo Departer")
      click_modal_button

      expect(page).to have_content("You are now signed out of Gather")
      expect(User.exists?(actor.id)).to be(false)
    end
  end
end
