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

    # One message per language the household's members read email in.
    def send_statement_notice(statement)
      data = {statement_id: statement.id}
      each_recipient_locale_group(statement.household, kind: :statement_notice, data: data) do |group|
        AccountMailer.with(recipient: group).statement_notice(statement).deliver_now
      end
    end
  end
end
