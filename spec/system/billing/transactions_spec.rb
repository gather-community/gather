# frozen_string_literal: true

require "rails_helper"

describe "adding a transaction", js: true do
  let(:actor) { create(:biller) }
  let!(:account) { create(:account, :no_activity, community: actor.community) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "picking a type from the charges and credits columns" do
    visit(new_account_transaction_path(account))

    within(".transaction-code-column", text: "Charges") do
      expect(page).to have_field("Meal charge")
      expect(page).to have_field("Membership dues charge")
      expect(page).to have_field("Payout to user")
      expect(page).to have_field("Other charge")
      expect(page).not_to have_field("Payment to community")
    end
    within(".transaction-code-column", text: "Credits") do
      expect(page).to have_field("Payment to community")
      expect(page).to have_field("Meal reimbursement credit")
      expect(page).to have_field("Other credit")
      expect(page).not_to have_field("Payout to user")
    end
    expect(page).to have_content("Charges increase what the household owes. Credits decrease it.")

    choose("Payout to user")
    fill_in("Amount", with: "20")
    click_button("Save")

    expect_validation_error("can't be blank")
    expect(page).to have_checked_field("Payout to user")

    fill_in("Description", with: "Refund of credit balance")
    click_button("Save")
    expect(page).to have_content("Below is how the new transaction will appear")
    expect(page).to have_content("Payout")
    click_button("Confirm")

    expect_success("Transaction added successfully.")
    transaction = Billing::Transaction.last
    expect(transaction.code).to eq("payout")
    expect(account.reload.total_new_charges).to eq(20)
  end

  scenario "submitting without a type" do
    visit(new_account_transaction_path(account))
    fill_in("Description", with: "Mystery")
    fill_in("Amount", with: "5")
    click_button("Save")

    expect_validation_error("can't be blank")
  end
end
