module Billing
  class Account < ApplicationRecord
    RECENT_STATEMENT_WINDOW = 24.hours

    acts_as_tenant :cluster

    belongs_to :household, inverse_of: :accounts
    belongs_to :community
    belongs_to :last_statement, class_name: "Billing::Statement"
    has_many :statements, ->{ order(created_at: :desc) }, dependent: :destroy
    has_many :transactions, dependent: :destroy

    scope :in_community, ->(c){ where(community_id: c.id) }
    scope :for_household, ->(h){ where(household_id: h.id) }
    scope :for_community_or_household,
      ->(c, h){ where("accounts.community_id = ? OR accounts.household_id = ?", c.id, h.id) }
    scope :with_balance_owing, ->{ where("accounts.balance_due > 0") }

    delegate :name, :no_users?, to: :household, prefix: true
    delegate :name, :abbrv, to: :community, prefix: true

    validates :credit_limit, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

    before_save do
      self.balance_due = (due_last_statement || 0) - total_new_credits
      self.current_balance = balance_due + total_new_charges
    end

    def self.by_cmty_and_household_name
      joins(household: :community).order("communities.name, households.name")
    end

    def self.with_recent_activity
      where("total_new_credits >= 0.01 OR total_new_charges >= 0.01
        OR ABS(current_balance) >= 0.01")
    end

    def self.for(household_id, community_id)
      find_or_create_by!(household_id: household_id, community_id: community_id)
    end

    def self.with_activity_and_users_and_no_recent_statement(community)
      with_activity(community).joins("LEFT JOIN statements ON statements.id = accounts.last_statement_id").
        where("statements.created_at <= ? OR statements.created_at IS NULL", RECENT_STATEMENT_WINDOW.ago).
        reject(&:household_no_users?)
    end

    def self.with_activity_but_no_users(community)
      with_activity(community).select(&:household_no_users?)
    end

    def self.with_activity(community)
      in_community(community).includes(:last_statement, household: [:users, :community]).with_recent_activity
    end

    def self.with_recent_statement(community)
      in_community(community).joins(:last_statement).
        where("statements.created_at > ?", RECENT_STATEMENT_WINDOW.ago)
    end

    # Returns accounts that have a balance OR a past statement AND an active household
    def self.with_any_activity(community)
      in_community(community).joins(:household)
        where("ABS(balance_due) >= 0.01 OR ABS(current_balance) >= 0.01 OR
          last_statement_id IS NOT NULL AND households.deactivated_at IS NULL")
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
      if transaction.charge?
        self.total_new_charges += transaction.amount
      else
        self.total_new_credits += transaction.abs_amount
      end
      save!
    end

    def recalculate!
      new_amounts = Billing::Transaction.select("
        SUM(CASE WHEN amount < 0 THEN amount ELSE 0 END) AS new_credits,
        SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS new_charges").
        where(account_id: id).
        where(statement_id: nil).to_a.first

      self.last_statement = statements.order(:created_at).last
      self.last_statement_on = last_statement.try(:created_on)
      self.due_last_statement = last_statement.try(:total_due)
      self.total_new_credits = new_amounts.try(:[], "new_credits").try(:abs) || 0
      self.total_new_charges = new_amounts.try(:[], "new_charges") || 0
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
