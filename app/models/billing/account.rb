# frozen_string_literal: true

# == Schema Information
#
# Table name: accounts
#
#  id                 :integer          not null, primary key
#  balance_due        :decimal(10, 2)   default(0.0), not null
#  credit_limit       :decimal(10, 2)
#  current_balance    :decimal(10, 2)   default(0.0), not null
#  due_last_statement :decimal(10, 2)
#  last_statement_on  :date
#  total_new_charges  :decimal(10, 2)   default(0.0), not null
#  total_new_credits  :decimal(10, 2)   default(0.0), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  cluster_id         :integer          not null
#  community_id       :integer          not null
#  household_id       :integer          not null
#  last_statement_id  :integer
#
# Indexes
#
#  index_accounts_on_cluster_id                     (cluster_id)
#  index_accounts_on_community_id                   (community_id)
#  index_accounts_on_community_id_and_household_id  (community_id,household_id) UNIQUE
#  index_accounts_on_household_id                   (household_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#  fk_rails_...  (household_id => households.id)
#  fk_rails_...  (last_statement_id => statements.id)
#
module Billing
  class Account < ApplicationRecord
    RECENT_STATEMENT_WINDOW = 24.hours

    acts_as_tenant :cluster

    self.table_name = "accounts"

    belongs_to :household, inverse_of: :accounts
    belongs_to :community
    belongs_to :last_statement, class_name: "Billing::Statement"
    has_many :statements, dependent: :destroy
    has_many :transactions, dependent: :destroy

    scope :in_community, ->(c) { where(community_id: c.id) }
    scope :for_household, ->(h) { where(household_id: h.id) }
    scope :for_community_or_household,
          ->(c, h) { where("accounts.community_id = ? OR accounts.household_id = ?", c.id, h.id) }
    scope :with_balance_owing, -> { where("accounts.balance_due > 0") }
    scope :by_cmty_and_household_name, lambda {
      joins(household: :community).order("communities.name, households.name")
    }
    scope :active, lambda { # Active means having new activity.
      where("total_new_credits >= 0.01 OR total_new_charges >= 0.01 OR ABS(current_balance) >= 0.01")
        .includes(:last_statement, household: %i[users community])
    }
    scope :with_recent_statement, lambda {
      joins(:last_statement).where("statements.created_at > ?", RECENT_STATEMENT_WINDOW.ago)
    }
    # Relevant means active OR belonging to an active household.
    scope :relevant, -> { joins(:household).active.or(joins(:household).merge(Household.active)) }

    delegate :name, :no_users?, to: :household, prefix: true
    delegate :name, :abbrv, to: :community, prefix: true

    validates :credit_limit, numericality: {greater_than_or_equal_to: 0}, allow_blank: true

    before_save do
      self.balance_due = (due_last_statement || 0) - total_new_credits
      self.current_balance = balance_due + total_new_charges
    end

    def self.with_activity_and_users_and_no_recent_statement
      active.joins("LEFT JOIN statements ON statements.id = accounts.last_statement_id")
        .where("statements.created_at <= ? OR statements.created_at IS NULL", RECENT_STATEMENT_WINDOW.ago)
        .reject(&:household_no_users?)
    end

    def self.with_activity_but_no_users
      active.select(&:household_no_users?)
    end

    # Updates account for latest statement. Assumes statement is latest one since the UI enforces this.
    def statement_added!(statement)
      self.last_statement_on = statement.created_on
      self.due_last_statement = statement.total_due
      self.last_statement = statement
      self.total_new_credits = 0
      self.total_new_charges = 0
      save!
    end

    def transaction_added!(transaction)
      if transaction.increaser?
        self.total_new_charges += transaction.value
      else
        self.total_new_credits += transaction.value
      end
      save!
    end

    def recalculate!
      increase_codes = Billing::Transaction::TYPES.select { |t| t.effect == :increase }.map(&:code)
      increase_codes = increase_codes.map { |c| "'#{c}'" }.join(",")
      new_amounts = Billing::Transaction.select("
        SUM(CASE WHEN code IN (#{increase_codes}) THEN value ELSE 0 END) AS new_charges,
        SUM(CASE WHEN code NOT IN (#{increase_codes}) THEN value ELSE 0 END) AS new_credits")
        .where(account_id: id)
        .where(statement_id: nil).to_a.first

      self.last_statement = statements.order(:created_at).last
      self.last_statement_on = last_statement&.created_on
      self.due_last_statement = last_statement&.total_due
      self.total_new_credits = new_amounts&.[]("new_credits")&.abs || 0
      self.total_new_charges = new_amounts&.[]("new_charges") || 0
      save!
    end

    def positive_current_balance?
      current_balance >= 0.01
    end

    def positive_balance_due?
      balance_due >= 0.01
    end

    def credit_exceeded?
      credit_limit && credit_limit < current_balance
    end
  end
end
