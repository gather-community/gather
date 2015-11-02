class StatementsController < ApplicationController
  load_and_authorize_resource

  def show
  end

  def generate
    Delayed::Job.enqueue(StatementJob.new(current_user.community))
    flash[:success] = "Statement generation started."
    redirect_to(accounts_path)
  end
end
