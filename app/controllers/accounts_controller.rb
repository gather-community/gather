class AccountsController < ApplicationController

  before_action -> { nav_context(:accounts) }

  def index
    @community = current_community
    authorize dummy_account
    @accounts = policy_scope(Billing::Account)
    @accounts = @accounts.where(community: @community).
      includes(:last_statement, household: [:users, :community]).
      with_any_activity(@community).
      by_household_full_name

    @active_accounts = Billing::Account.with_activity(@community).count
    @no_user_accounts = Billing::Account.with_activity_but_no_users(@community).count
    @recent_stmt_accounts = Billing::Account.with_recent_statement(@community).count

    last_statement = Billing::Statement.for_community(@community).order(:created_at).last
    @last_statement_run = last_statement.try(:created_on)

    @late_fee_count = late_fee_applier.policy? ? late_fee_applier.late_accounts.count : 0

    last_fee = Billing::Transaction.joins(:account).
      where(code: "late_fee", accounts: { community_id: @community.id }).
      order(:incurred_on).last

    @late_fee_days_ago = last_fee.nil? ? nil : (Date.today - last_fee.incurred_on).to_i
  end

  def show
    @account = Billing::Account.find(params[:id])
    @community = @account.community
    authorize @account
    @statements = @account.statements.page(params[:page]).per(StatementsController::PER_PAGE)
    @last_statement = @account.last_statement
  end

  def edit
    @account = Billing::Account.find(params[:id])
    authorize @account
  end

  def update
    @account = Billing::Account.find(params[:id])
    authorize @account
    if @account.update_attributes(account_params)
      flash[:success] = "Account updated successfully."
      redirect_to(accounts_path)
    else
      set_validation_error_notice
      render(:edit)
    end
  end

  def apply_late_fees
    authorize dummy_account
    late_fee_applier.apply!
    flash[:success] = "Late fees applied."
    redirect_to(accounts_path)
  end

  private

  def dummy_account
    Billing::Account.new(community: current_community)
  end

  # Pundit built-in helper doesn't work due to namespacing
  def account_params
    params.require(:billing_account).permit(policy(@account).permitted_attributes)
  end

  def late_fee_applier
    @late_fee_applier ||= Billing::LateFeeApplier.new(current_community)
  end
end
