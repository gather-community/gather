# frozen_string_literal: true

class AccountsController < ApplicationController
  before_action -> { nav_context(:accounts) }

  decorates_assigned :accounts, :account, :last_statement, :community, :statements

  def index
    authorize(sample_account)
    @community = current_community
    @accounts = policy_scope(Billing::Account)
    @accounts = @accounts.where(community: @community)
      .includes(:last_statement, household: %i[users community])
      .with_any_activity(@community)
      .by_cmty_and_household_name

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
    @statement_accounts = Billing::Account.with_activity_and_users_and_no_recent_statement(@community).count
    @active_accounts = Billing::Account.with_activity(@community).count
    @no_user_accounts = Billing::Account.with_activity_but_no_users(@community).count
    @recent_stmt_accounts = Billing::Account.with_recent_statement(@community).count

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
    prepare_lenses(community: {required: true, subdomain: false})
    if lenses[:community].value&.match(Community::SLUG_REGEX)
      Community.find_by(slug: lenses[:community].value)
    elsif lenses[:community].value&.match(/\d+/)
      Community.find(lenses[:community].value)
    else
      current_user.community
    end
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

  def prep_account_vars
    @statements = @account.statements.page(params[:page] || 1).per(StatementsController::PER_PAGE)
    @last_statement = @account.last_statement
    @has_activity = @account.transactions.any?
  end
end
