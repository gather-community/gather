# Sends invoices to accounts from the given community with current activity.
InviteJob = Struct.new(:community) do
  def perform
    @accounts = Account.for_community(community).includes(:household, :last_invoice).
      where("total_new_credits >= 0.01 OR total_new_charges >= 0.01 OR current_balance >= 0.01")

    @accounts.each do |account|
      begin
        invoice = Invoice.new(
          household: account.household,
          prev_balance: account.last_invoice.try(:total_due)
        ).populate!
        NotificationMailer.invoice_notice(invoice).deliver_now
      rescue InvoiceError
        ExceptionNotifier.notify_exception($!, data: {account_id: account.id})
      end
    end
  end

  def max_attempts
    3
  end

  def error(job, exception)
    ExceptionNotifier.notify_exception(exception, data: {community_id: community.id})
  end
end
