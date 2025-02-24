# frozen_string_literal: true

# == Schema Information
#
# Table name: statements
#
#  id            :integer          not null, primary key
#  due_on        :date
#  prev_balance  :decimal(10, 2)   not null
#  prev_stmt_on  :date
#  reminder_sent :boolean          default(FALSE), not null
#  total_due     :decimal(10, 2)   not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :integer          not null
#  cluster_id    :integer          not null
#
# Indexes
#
#  index_statements_on_account_id  (account_id)
#  index_statements_on_cluster_id  (cluster_id)
#  index_statements_on_created_at  (created_at)
#  index_statements_on_due_on      (due_on)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (cluster_id => clusters.id)
#
module Billing
  class Statement < ApplicationRecord
    include TimeCalculable
    # Used to compute an assumed due date when community has no due date policy.
    # Used when e.g. determining when to send payment reminders.
    DEFAULT_TERMS = 30.days
    DUE_DATE_EXPR = "COALESCE(due_on, statements.created_at + INTERVAL '1' DAY * #{DEFAULT_TERMS / 1.day})"

    acts_as_tenant :cluster

    self.table_name = "statements"

    belongs_to :account, inverse_of: :statements
    has_many :transactions, -> { oldest_first }, dependent: :nullify

    scope :in_community, ->(c) { joins(:account).where(accounts: {community_id: c.id}) }
    scope :for_household, ->(h) { joins(:account).where(accounts: {household_id: h.id}) }
    scope :for_community_or_household,
          ->(c, h) { joins(:account).merge(Billing::Account.for_community_or_household(c, h)) }
    scope :reminder_not_sent, -> { where(reminder_sent: false) }
    scope :with_balance_owing, -> { joins(:account).merge(Billing::Account.with_balance_owing) }
    scope :is_latest, -> { joins(:account).where("accounts.last_statement_id = statements.id") }
    scope :newest_first, -> { order(created_at: :desc) }

    delegate :community, :community_id, :household, :household_id, to: :account

    paginates_per 10

    def self.due_within_days_from_now(days)
      within_days_from_now(DUE_DATE_EXPR, days)
    end

    after_create do
      account.statement_added!(self)
    end

    before_destroy do
      if account.last_statement_id == id
        account.last_statement = nil
        account.save!
      end
    end

    after_destroy do
      account.recalculate!
    end

    # Populates the statement with available line items.
    # Raises StatementError unless the balance is nonzero or there are any line items.
    def populate!
      self.transactions = Billing::Transaction.where(account: account).no_statement.to_a
      self.total_due = prev_balance + transactions.map(&:amount).sum
      self.prev_stmt_on = account.last_statement.try(:created_on)
      self.due_on = terms > 0 ? (Time.current + terms.days).to_date : nil

      if transactions.empty? && total_due.abs < 0.01
        raise StatementError, "Must have line items or a total due."
      else
        save!
      end
    end

    def new_charges
      total_due - prev_balance
    end

    def created_on
      created_at.try(:to_date)
    end

    private

    def terms
      community.settings.billing.statement_terms
    end
  end

  class StatementError < StandardError; end
end
