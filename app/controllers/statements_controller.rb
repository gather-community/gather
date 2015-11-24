class StatementsController < ApplicationController
  load_and_authorize_resource

  def show
    @charges = @statement.transactions.select(&:charge?)
    @credits = @statement.transactions.select(&:credit?)
    @community = @statement.community
  end

  def generate
    Delayed::Job.enqueue(StatementJob.new(current_user.community))

    flash[:success] = "Statement generation started. Please try refreshing the page in a moment to see updated account statuses."

    if (no_users = Account.with_activity_but_no_users(current_user.community)).any?
      flash[:alert] = "The following households have no associated users and thus "\
        "statements were not generated for them: " << (no_users.map(&:household_full_name).join(", ")) <<
        ". Try sending statements again once the households have associated users."
    end

    redirect_to(accounts_path)
  end

  def more
    @account = Account.find(params[:account_id])
    authorize!(:read, @account)
    @statements = @account.statements.page(params[:page])
    render(partial: "households/statement_rows")
  end
end
