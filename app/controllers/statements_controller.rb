class StatementsController < ApplicationController
  load_and_authorize_resource

  def show
    @charges = @statement.line_items.select(&:charge?)
    @credits = @statement.line_items.select(&:credit?)
  end

  def generate
    Delayed::Job.enqueue(StatementJob.new(current_user.community))
    flash[:success] = "Statement generation started."
    redirect_to(accounts_path)
  end

  def more
    @account = Account.find(params[:account_id])
    authorize!(:read, @account)
    @statements = @account.statements.page(params[:page])
    render(partial: "households/statement_rows")
  end
end
