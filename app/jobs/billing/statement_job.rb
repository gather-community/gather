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
      with_cluster(community.cluster) do
        Account.in_community(community).with_activity_and_users_and_no_recent_statement.each do |account|
          # Run in a transaction so that if there is an issue sending the statement,
          # it gets rolled back.
          Statement.transaction do
            with_mail_delivery_resilience do
              statement = Statement.new(account: account,
                prev_balance: account.last_statement&.total_due || 0)
              statement.populate!
              send_statement_notice(statement) unless options[:no_mail]
            end
          end
        rescue StatementError => e
          Gather::ErrorReporter.instance.report(e, data: {account_id: account.id})
        end
      end
    end

    # One message per household member, so a bad address only affects that person. On a shared message
    # the server's rejection of one address stopped the message for everyone else on it.
    def send_statement_notice(statement)
      data = {statement_id: statement.id}
      each_notification_recipient(statement.household, kind: :statement_notice, data: data) do |user|
        AccountMailer.with(recipient: user).statement_notice(statement).deliver_now
      end
    end
  end
end
