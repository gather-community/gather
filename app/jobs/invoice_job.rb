# Sends invoices to accounts from the given community with current activity.
InvoiceJob = Struct.new(:community) do
  def perform
    @accounts = Account.for_community(community).includes(:household, :last_invoice).with_recent_activity
    @accounts.each do |account|
      begin
        invoice = Invoice.new(
          account: account,
          prev_balance: account.last_invoice.try(:total_due) || 0
        )
        invoice.populate!
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
