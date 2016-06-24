class AccountsController < ApplicationController

  def index
    authorize Account
    @accounts = policy_scope(Account)
    @community = community
    @accounts = @accounts.where(community: @community).
      includes(:last_statement, household: [:users, :community]).
      with_any_activity(community).
      by_household_full_name

    @active_accounts = Account.with_activity(community).count
    @no_user_accounts = Account.with_activity_but_no_users(community).count
    @recent_stmt_accounts = Account.with_recent_statement(community).count

    last_statement = Statement.for_community(community).order(:created_at).last
    @last_statement_run = last_statement.try(:created_on)

    @late_fee_count = late_fee_applier.policy? ? late_fee_applier.late_accounts.count : 0

    last_fee = Transaction.joins(:account).
      where(code: "late_fee", accounts: { community_id: community.id }).
      order(:incurred_on).last

    @late_fee_days_ago = last_fee.nil? ? nil : (Date.today - last_fee.incurred_on).to_i
  end

  def show
    @account = Account.find(params[:id])
    authorize @account
    @statements = @account.statements.page(params[:page]).per(StatementsController::PER_PAGE)
    @last_statement = @account.last_statement
  end

  def edit
    @account = Account.find(params[:id])
    authorize @account
  end

  def update
    @account = Account.find(params[:id])
    authorize @account
    if @account.update_attributes(permitted_attributes(@account))
      flash[:success] = "Account updated successfully."
      redirect_to(accounts_path)
    else
      set_validation_error_notice
      render(:edit)
    end
  end

  def apply_late_fees
    authorize Account
    late_fee_applier.apply!
    flash[:success] = "Late fees applied."
    redirect_to(accounts_path)
  end

  def apply_payments
    if params[:confirmed]
      Account.find(params[:payment].keys).each{ |a| authorize a }
      PaymentApplier.new(params[:payment]).apply!
      flash[:success] = "Payments applied."
      redirect_to(accounts_path)
    else
      # Build set of payment hashes to confirm with the user.
      @accounts = Account.where(id: params[:payment].reject{ |_, a| a.blank? }.keys).by_household_full_name
      @payments = @accounts.map do |account|
        authorize @account
        { account: account, amount: params[:payment][account.id.to_s] }
      end
    end
  end

  private

  def account_params
    params.require(:account).permit(:credit_limit)
  end

  def community
    current_user.community
  end

  def late_fee_applier
    @late_fee_applier ||= LateFeeApplier.new(community)
  end
end
