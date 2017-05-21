# Sends statements to accounts from the given community with current activity.
module Billing
  class StatementJob < ApplicationJob
    attr_reader :community_id

    def initialize(community_id)
      @community_id = community_id
    end

    def perform
      with_tenant_from_community_id(community_id) do
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
    end

    private

    def community
      Community.find(community_id)
    end

    def error_report_data
      {community_id: community_id}
    end
  end
end
