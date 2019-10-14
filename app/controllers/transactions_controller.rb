# frozen_string_literal: true

class TransactionsController < ApplicationController
  before_action -> { nav_context(:accounts) }

  decorates_assigned :account, :transaction, :transactions, :last_statement

  def index
    @account = Billing::Account.find(params[:account_id]).decorate
    @last_statement = @account.last_statement
    authorize(@account, :show?)
    authorize(Billing::Transaction)
    @transactions = policy_scope(Billing::Transaction).includes(account: :community)
      .where(account: @account).no_statement.oldest_first
    @community = @account.community
  end

  def new
    @account = Billing::Account.find(params[:account_id])
    authorize(@account, :update?)
    @transaction = Billing::Transaction.new(incurred_on: Time.zone.today, account: @account).decorate
    authorize(@transaction)
  end

  def create
    @account = Billing::Account.find(params[:account_id])
    authorize(@account, :update?)
    @transaction = Billing::Transaction.new(account: @account)
    authorize(@transaction)
    @transaction.assign_attributes(transaction_params)
    if @transaction.valid?
      handle_confirmation_flow
    else
      render(:new)
    end
  end

  private

  def handle_confirmation_flow
    if params[:confirmed] == "1"
      @transaction.save
      flash[:success] = "Transaction added successfully."
      redirect_to(accounts_path)
    elsif params[:confirmed] == "0"
      flash.now[:notice] = "The transaction was not added. You can edit it below and try again, "\
         "or click 'Cancel' below to return to the accounts page."
      render(:new)
    else
      render(:confirm)
    end
  end

  # Pundit built-in helper doesn't work due to namespacing
  def transaction_params
    params.require(:billing_transaction).permit(policy(@transaction).permitted_attributes)
  end
end
