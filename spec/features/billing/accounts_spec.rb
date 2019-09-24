# frozen_string_literal: true

require "rails_helper"

feature "accounts", js: true do
  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  describe "biller view" do
    let(:actor) { create(:biller) }
    let!(:account1) { create(:account, :with_statement, :with_transactions) }
    let!(:account2) { create(:account, :with_statement, :with_transactions) }
    let!(:txn_description) { account1.transactions[0].description }
    let!(:stmt_amt) { account1.statements[0].total_due }

    before do
      actor.community.settings.billing.late_fee_policy.fee_type = "fixed"
      actor.community.settings.billing.late_fee_policy.threshold = 1.00
      actor.community.settings.billing.late_fee_policy.amount = 2.51
      actor.community.save!
    end

    scenario do
      visit(accounts_path)
      expect(page).to have_content(account1.household.name)
      expect(page).to have_content(account2.household.name)

      click_link(account1.household.name)
      expect(page).to have_content("Balance Due $#{stmt_amt}")

      click_link("Edit")
      fill_in("Credit Limit", with: "200")
      click_button("Save")
      expect_success("Account updated successfully.")

      click_link(account1.household.name)
      find(:xpath, "//tr[td[contains(text(), 'New Charges')]]//a").click
      expect(page).to have_content("Recent Activity")
      page.go_back

      within("table.statements") { click_link("$#{stmt_amt}") }
      expect(page).to have_content(txn_description)
      page.go_back

      click_link("Add Transaction")
      choose("Payment")
      fill_in("Description", with: "Check #123")
      fill_in("Amount", with: "43.55")
      click_button("Save")

      expect(page).to have_content("Below is how the new transaction will appear")
      click_button("Confirm")
      expect_success("Transaction added successfully.")

      message = accept_confirm { click_link("Apply Late Fees") }
      expect(message).to include("Are you sure? Fees will be charged to 1 households")
      expect_success("Late fees applied")
      click_link(account2.household.name)
      find(:xpath, "//tr[td[contains(text(), 'New Charges')]]//a").click
      expect(page).to have_content("Late payment fee $2.51")
      click_link("Accounts")

      message = accept_confirm { click_link("Send Statements") }
      expect(message).to include("Are you sure? Statements will be sent out to 2 households.")
      expect_success("Statement generation started.")
      process_queued_job

      click_link(account1.household.name)
      expect(page).to have_css("table.statements tbody tr", count: 3) # Header plus 2 statements
    end
  end
end
