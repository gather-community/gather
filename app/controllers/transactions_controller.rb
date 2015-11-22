class TransactionsController < ApplicationController
  before_action :load_and_authorize_account
  load_resource
  skip_authorize_resource

  def new
    @transaction = Transaction.new(incurred_on: Date.today, account_id: params[:account_id])
  end

  def create
    @transaction.account = @account
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

  private

  def transaction_params
    params.require(:transaction).permit(:incurred_on, :code, :description, :amount)
  end

  def load_and_authorize_account
    @account = Account.find(params[:account_id])
    authorize!(:manage, @account)
  end
end
