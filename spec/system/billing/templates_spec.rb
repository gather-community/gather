# frozen_string_literal: true

require "rails_helper"

describe "billing templates", js: true do
  let(:actor) { create(:biller) }
  let!(:memtype1) { create(:member_type, name: "Foo", community: actor.community) }
  let!(:memtype2) { create(:member_type, name: "Bar", community: actor.community) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "with no existing templates" do
    scenario "create, edit, delete" do
      visit(billing_templates_path)
      expect(page).to have_content("No templates found")

      click_link("Create Template")
      select2("Foo", from: "#billing_template_member_type_ids", multiple: true)
      select2("Bar", from: "#billing_template_member_type_ids", multiple: true)
      choose("Payment")
      click_button("Save")

      expect_validation_error("can't be blank")
      fill_in("Description", with: "Automatic payment")
      fill_in("Amount", with: 12.34)
      click_button("Save")

      expect_success
      expect(page).to have_content("Automatic payment")
      expect(page).to have_content("$12.34")
      click_link("Automatic payment")

      fill_in("Amount", with: 12.35)
      click_button("Save")

      expect_success
      expect(page).not_to have_content("$12.34")
      expect(page).to have_content("$12.35")

      click_link("Automatic payment")
      accept_confirm { click_link("Delete") }

      expect_success
      expect(page).to have_content("No templates found")
    end
  end

  context "with existing templates" do
    let!(:household) { create(:household, member_type: memtype1) }
    let!(:template1) { create(:billing_template, description: "Apple", member_types: [memtype1]) }
    let!(:template2) { create(:billing_template, description: "Banana", member_types: [memtype2]) }
    let!(:template3) { create(:billing_template, description: "Cumquat", member_types: [memtype1]) }

    scenario "apply" do
      visit(billing_templates_path)
      click_link("Apply Templates")
      expect_alert("select at least one")

      find("tr", text: "Apple").find("input[type=checkbox]").check
      find("tr", text: "Banana").find("input[type=checkbox]").check
      click_link("Apply Templates")

      expect(page).to have_content("about to create the following")
      expect(page).to have_content("Apple")
      expect(page).to have_content("Banana")
      expect(page).not_to have_content("Cumquat")
      click_button("Cancel")

      expect(page).not_to have_success
      expect(Billing::Transaction.count).to be_zero
      find("tr", text: "Apple").find("input[type=checkbox]").check
      find("tr", text: "Banana").find("input[type=checkbox]").check
      click_link("Apply Templates")
      click_button("Apply")

      expect_success("created")

      visit(account_transactions_path(household.accounts[0]))
      expect(page).to have_content("Apple")
      expect(page).not_to have_content("Banana")
      expect(page).not_to have_content("Cumquat")
    end
  end
end
