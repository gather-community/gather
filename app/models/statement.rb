class Statement < ActiveRecord::Base
  belongs_to :account, inverse_of: :statements
  has_many :transactions, ->{ order(:incurred_on) }, dependent: :nullify

  scope :for_community, ->(c){ joins(account: :household).where("households.community_id = ?", c.id) }
  scope :for_community_or_household,
    ->(c,h){ joins(account: :household).where("households.community_id = ? OR households.id = ?", c.id, h.id) }

  delegate :community, :community_id, :household, :household_id, :household_full_name, to: :account

  paginates_per 10

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
    self.transactions = Transaction.where(account: account).no_statement.to_a
    self.total_due = prev_balance + transactions.map(&:amount).sum
    self.prev_stmt_on = account.last_statement.try(:created_on)

    if transactions.empty? && total_due.abs < 0.01
      raise StatementError.new("Must have line items or a total due.")
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
end

class StatementError < StandardError; end