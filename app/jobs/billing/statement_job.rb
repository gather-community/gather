# frozen_string_literal: true

module Billing
  # Sends statements to accounts from the given community with current activity.
  class StatementJob < ApplicationJob
    attr_reader :community_id, :options

    def perform(community_id, options = {})
      @community_id = community_id
      @options = options
      send_statements
    end

    private

    def send_statements
      with_community(community) do
        Account.with_activity_and_users_and_no_recent_statement(community).each do |account|
          # Run in a transaction so that if there is an issue sending the statement,
          # it gets rolled back.
          Statement.transaction do
            statement = Statement.new(account: account, prev_balance: account.last_statement&.total_due || 0)
            statement.populate!
            AccountMailer.statement_notice(statement).deliver_now unless options[:no_mail]
          end
        rescue StatementError => e
          ExceptionNotifier.notify_exception(e, data: {account_id: account.id})
        end
      end
    end
  end
end
