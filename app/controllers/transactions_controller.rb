class TransactionsController < ApplicationController
  def index
    @account = Account.find(params[:account_id])
    authorize @account, :show?
    authorize Transaction
    @transactions = policy_scope(Transaction)
    @transactions = @transactions.where(account: @account).no_statement
    @charges = @transactions.select(&:charge?)
    @credits = @transactions.select(&:credit?)
    @community = @account.community
  end

  def new
    @account = Account.find(params[:account_id])
    authorize @account, :update?
    @transaction = Transaction.new(incurred_on: Date.today, account: @account)
    authorize @transaction
  end

  def create
    @account = Account.find(params[:account_id])
    authorize @account, :update?
    @transaction = Transaction.new(account: @account)
    authorize @transaction
    @transaction.assign_attributes(permitted_attributes(@transaction))
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
end
