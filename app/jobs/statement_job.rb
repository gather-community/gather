# Sends statements to accounts from the given community with current activity.
StatementJob = Struct.new(:community) do
  def perform
    Account.with_activity_and_users_and_no_recent_statement(community).each do |account|
      begin
        # Run in a transaction so that if there is an issue sending the statement,
        # it gets rolled back.
        Statement.transaction do
          statement = Statement.new(
            account: account,
            prev_balance: account.last_statement.try(:total_due) || 0
          )
          statement.populate!
          AccountMailer.statement_notice(statement).deliver_now
        end
      rescue StatementError
        ExceptionNotifier.notify_exception($!, data: {account_id: account.id})
      end
    end
  end

  def max_attempts
    1
  end

  def error(job, exception)
    ExceptionNotifier.notify_exception(exception, data: {community_id: community.id})
  end
end
