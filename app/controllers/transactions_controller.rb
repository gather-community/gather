class TransactionsController < ApplicationController
  def index
    @account = Billing::Account.find(params[:account_id])
    authorize @account, :show?
    authorize Billing::Transaction
    @transactions = policy_scope(Billing::Transaction)
    @transactions = @transactions.where(account: @account).no_statement
    @charges = @transactions.select(&:charge?)
    @credits = @transactions.select(&:credit?)
    @total_charges = @charges.sum(&:amount)
    @total_credits = @credits.sum(&:amount)
    @community = @account.community
  end

  def new
    @account = Billing::Account.find(params[:account_id])
    authorize @account, :update?
    @transaction = Billing::Transaction.new(incurred_on: Date.today, account: @account)
    authorize @transaction
  end

  def create
    @account = Billing::Account.find(params[:account_id])
    authorize @account, :update?
    @transaction = Billing::Transaction.new(account: @account)
    authorize @transaction
    @transaction.assign_attributes(transaction_params)
    if @transaction.valid?
      # If confirmed not present, we show a confirm screen.
      if params[:confirmed] == "1"
        @transaction.save
        flash[:success] = "Transaction added successfully."
        redirect_to accounts_path
      elsif params[:confirmed] == "0"
        flash.now[:notice] = "The transaction was not added. You can edit it below and try again, "\
           "or click 'Cancel' below to return to the accounts page."
        render :new
      else
        render :confirm
      end
    else
      set_validation_error_notice
      render :new
    end
  end

  # Pundit built-in helper doesn't work due to namespacing
  def transaction_params
    params.require(:billing_transaction).permit(policy(@transaction).permitted_attributes)
  end
end
