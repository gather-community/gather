# Sends statements to accounts from the given community with current activity.
StatementJob = Struct.new(:community) do
  def perform
    @accounts = Account.for_community(community).includes(:household, :last_statement).with_recent_activity
    @accounts.each do |account|
      begin
        statement = Statement.new(
          account: account,
          prev_balance: account.last_statement.try(:total_due) || 0
        )
        statement.populate!
        NotificationMailer.statement_notice(statement).deliver_now
      rescue StatementError
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
