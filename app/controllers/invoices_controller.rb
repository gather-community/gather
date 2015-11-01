class InvoicesController < ApplicationController
  load_and_authorize_resource

  def show
  end

  def generate
    Delayed::Job.enqueue(InvoiceJob.new(current_user.community))
    flash[:success] = "Invoice generation started."
    redirect_to(accounts_path)
  end
end
