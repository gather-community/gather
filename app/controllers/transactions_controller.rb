# frozen_string_literal: true

class TransactionsController < ApplicationController
  before_action -> { nav_context(:accounts) }

  decorates_assigned :account, :transaction, :transactions, :last_statement

  def index
    respond_to do |format|
      format.html { index_html }
      format.csv { index_csv }
    end
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

  def index_html
    # params[:account_id] (via nested route) is required for the HTML case but not CSV
    @account = Billing::Account.find(params[:account_id]).decorate
    @last_statement = @account.last_statement
    authorize(@account, :show?)
    authorize(Billing::Transaction)
    @transactions = policy_scope(Billing::Transaction).includes(account: :community)
      .where(account: @account).no_statement.oldest_first
    @community = @account.community
  end

  def index_csv
    transactions = policy_scope(Billing::Transaction).incurred_between(*params[:dates].split("-"))
    transactions = transactions.includes(account: :household)
    transactions = if params[:account_id]
                     transactions.where(account_id: params[:account_id])
                   else
                     transactions.in_community(current_community)
                   end
    transactions = transactions.order(:incurred_on, "households.name", :code, :description)
    filename_chunk = params[:account_id] ? "account-#{params[:account_id]}" : :community
    filename = csv_filename(filename_chunk, "transactions", params[:dates])
    csv = Billing::TransactionCsvExporter.new(transactions, policy: policy(sample_transaction)).to_csv
    send_data(csv, filename: filename, type: :csv)
  end

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

  def sample_transaction
    Billing::Transaction.new
  end
end
