# frozen_string_literal: true

class AccountsController < ApplicationController
  before_action -> { nav_context(:billing, :accounts) }

  decorates_assigned :accounts, :account, :last_statement, :community, :statements

  def index
    authorize(sample_account)
    prepare_lenses(:"billing/account_active")
    @community = current_community
    @accounts = policy_scope(Billing::Account)
    @accounts = @accounts.where(community: @community)
      .includes(:last_statement, household: %i[users community])
      .by_cmty_and_household_name

    # If they ask for 'all accounts' in the lens, we still only show relevant ones, which are those
    # that are active OR attached to active households. If household and account are BOTH inactive
    # then it's unlikely anyone would ever care. If they do, we can add another option to lens.
    @accounts = lenses[:active].value == "active_only" ? @accounts.active : @accounts.relevant

    @txn_ranges = transaction_ranges(max_range: Billing::Transaction.date_range(community: @community))
    @totals = build_account_totals

    respond_to do |format|
      format.html { index_html }
      format.csv { index_csv }
    end
  end

  def yours
    authorize(sample_account)
    @household = current_user.household
    @accounts = policy_scope(@household.accounts).includes(:community).to_a
    @community = prepare_lens_and_get_community
    @account = @accounts.detect { |a| a.community == @community } || @accounts.first
    prep_account_vars if @account
  end

  def show
    @account = Billing::Account.find(params[:id]).decorate
    @community = @account.community
    authorize(@account)
    @txn_ranges = transaction_ranges(max_range: Billing::Transaction.date_range(account: @account))
    prep_account_vars
  end

  def edit
    @account = Billing::Account.find(params[:id]).decorate
    authorize(@account)
  end

  def update
    @account = Billing::Account.find(params[:id])
    authorize(@account)
    if @account.update(account_params)
      flash[:success] = "Account updated successfully."
      redirect_to(accounts_path)
    else
      render(:edit)
    end
  end

  def apply_late_fees
    authorize(sample_account)
    late_fee_applier.apply!
    flash[:success] = "Late fees applied."
    redirect_to(accounts_path)
  end

  private

  def index_html
    @accounts = @accounts.decorate
    community_accounts = Billing::Account.in_community(@community)
    @active_accounts = community_accounts.active.count
    @statement_accounts = community_accounts.with_activity_and_users_and_no_recent_statement.count
    @no_user_accounts = community_accounts.with_activity_but_no_users.count
    @recent_stmt_accounts = community_accounts.with_recent_statement.count

    last_statement = Billing::Statement.in_community(@community).order(:created_at).last
    @last_statement_run = last_statement&.created_on

    last_fee = Billing::Transaction.joins(:account)
      .where(code: "late_fee", accounts: {community_id: @community.id})
      .order(:incurred_on).last
    @late_fee_days_ago = last_fee.nil? ? nil : (Time.zone.today - last_fee.incurred_on).to_i
    @late_fee_count = late_fee_applier.policy? ? late_fee_applier.late_accounts.count : 0
  end

  def index_csv
    filename = csv_filename(:community, "accounts", :date)
    csv = Billing::AccountCsvExporter.new(@accounts, policy: policy(sample_account)).to_csv
    send_data(csv, filename: filename, type: :csv)
  end

  def prepare_lens_and_get_community
    return current_user.community unless @accounts.many?
    prepare_lenses(community: {clearable: false, subdomain: false})
    lenses[:community].selection
  end

  def sample_account
    Billing::Account.new(community: current_community)
  end

  # Pundit built-in helper doesn't work due to namespacing
  def account_params
    params.require(:billing_account).permit(policy(@account).permitted_attributes)
  end

  def late_fee_applier
    @late_fee_applier ||= Billing::LateFeeApplier.new(current_community)
  end

  def build_account_totals
    totals = {due_last_statement: 0, total_new_credits: 0, balance_due: 0,
            total_new_charges: 0, current_balance: 0}
    @accounts.each do |account|
      totals.keys.each { |k| totals[k] += (account.send(k) || 0) }
    end
    totals
  end

  def prep_account_vars
    @statements = @account.statements.order(created_at: :desc).page(params[:page] || 1).per(StatementsController::PER_PAGE)
    @last_statement = @account.last_statement
    @has_activity = @account.transactions.any?
  end

  def transaction_ranges(max_range:)
    builder = DateRangeBuilder.new(max_range: max_range, trim_ranges: false)
    builder.add_months(4)
    builder.add_quarters(4)
    builder.add_years
    builder.add_all_time
    builder.pairs
  end
end
