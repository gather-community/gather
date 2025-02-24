# frozen_string_literal: true

require "rails_helper"

describe "accounts", js: true do
  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  describe "biller view" do
    let(:actor) { create(:biller) }
    let!(:account1) { create(:account, :with_statement, :with_transactions) }
    let!(:account2) { create(:account, :with_statement, :with_transactions) }
    let!(:account3) { create(:account, :no_activity) }
    let!(:txn_description) { account1.transactions[0].description }
    let!(:stmt_amt) { account1.statements.order(created_at: :desc)[0].total_due }
    let!(:late_recorded_txn) do
      create(:transaction, account: account1, incurred_on: Time.zone.today - 1.year,
                           description: "Ye olde transaction")
    end

    before do
      actor.community.settings.billing.late_fee_policy.fee_type = "fixed"
      actor.community.settings.billing.late_fee_policy.threshold = 1.00
      actor.community.settings.billing.late_fee_policy.amount = 2.51
      actor.community.save!
    end

    scenario "main path", :perform_jobs do
      visit(accounts_path)
      expect(page).to have_content(account1.household.name)
      expect(page).to have_content(account2.household.name)
      expect(page).to have_content(account3.household.name)

      select_lens(:active, "Show Active Only")
      expect(page).not_to have_content(account3.household.name)

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
      click_link("Billing")

      message = accept_confirm { click_link("Send Statements") }
      expect(message).to include("Are you sure? Statements will be sent out to 2 households.")
      expect_success("Statement generation started.")

      click_link(account1.household.name)
      expect(page).to have_statement_rows(2, more: false)
    end

    scenario "download account csv" do
      Timecop.freeze("2017-04-15 12:00pm") do
        visit(accounts_path)
        click_link("Download Accounts as CSV")
        wait_for_download
        expect(download_content).to match(/Number,Household ID/)
        expect(download_filename).to eq("#{account1.community.slug}-accounts-2017-04-15.csv")
      end
    end

    scenario "download all transaction csv" do
      visit(accounts_path)
      click_link("Download Transactions as CSV")
      year = account1.transactions[0].incurred_on.year
      select(year, from: "dates")
      wait_for_download
      expect(download_content).to match(/"ID",Date/)
      expect(download_filename)
        .to eq("#{account1.community.slug}-transactions-incd-#{year}0101-#{year}1231.csv")
    end

    scenario "download account transaction csv by date incurred" do
      visit(account_path(account1))
      click_link("Download Transactions as CSV")
      year = account1.transactions[0].incurred_on.year
      select(year, from: "dates")
      wait_for_download
      expect(download_content).to match(/"ID",Date/)
      expect(download_content).not_to match(/Ye olde transaction/)
      expect(download_filename).to eq("account-#{account1.id}-transactions-incd-#{year}0101-#{year}1231.csv")
    end

    scenario "download account transaction csv by date recorded" do
      visit(account_path(account1))
      click_link("Download Transactions as CSV")
      year = Time.zone.today.year
      select("Recorded within ...", from: "col")
      select(year, from: "dates")
      wait_for_download
      expect(download_content).to match(/Ye olde transaction/)
      expect(download_filename).to eq("account-#{account1.id}-transactions-recd-#{year}0101-#{year}1231.csv")
    end
  end

  describe "user view" do
    let(:household) { create(:household, skip_listener_action: :account_create) }
    let(:actor) { create(:user, household: household) }
    let(:community1) { actor.community }
    let!(:community2) { create(:community) }
    let!(:account1) { create(:account, :with_statement, :with_transactions, household: household) }
    let!(:account2) { create(:account, :with_transactions, community: community2, household: household) }
    let!(:past_statements) do
      # Create lots of old statements so we can test pagination
      10.times do |i|
        Timecop.freeze(-i.weeks) do
          create(:statement, account: account1, prev_balance: 3.50, total_due: i.to_f + 0.25)
        end
      end
    end

    scenario "page view and load more statements" do
      visit(root_path)
      click_on_personal_nav("Accounts")
      expect(page).to have_content("Your #{community1.name} Account")

      expect(page).to have_statement_rows(5, more: true)
      click_link("Load More...")
      expect(page).to have_statement_rows(10, more: true)
    end

    scenario "lens" do
      visit(yours_accounts_path)
      expect(lens_selected_option(:community).text).to eq(community1.name)
      select_lens(:community, community2.name)
      expect(page).to have_content("Your #{community2.name} Account")
      expect(lens_selected_option(:community).text).to eq(community2.name)
      expect(page).not_to have_lens_clear_link

      # Should remember selected community.
      visit(yours_accounts_path)
      expect(page).to have_content("Your #{community2.name} Account")
    end
  end

  def have_statement_rows(count, more:)
    # Account for header row and more link
    have_css("table.statements tbody tr", count: count + (more ? 2 : 1))
  end
end
