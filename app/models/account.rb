class Account < ActiveRecord::Base
  belongs_to :household, inverse_of: :accounts
  belongs_to :community
  belongs_to :last_statement, class_name: "Statement"
  has_many :statements, ->{ order(created_at: :desc) }
  has_many :line_items

  scope :for_community, ->(c){ where(community_id: c.id) }
  scope :for_community_or_household,
    ->(c, h){ where("accounts.community_id = ? OR accounts.household_id = ?", c.id, h.id) }

  delegate :name, :full_name, to: :household, prefix: true

  before_save do
    self.balance_due = (due_last_statement || 0) - total_new_credits
    self.current_balance = balance_due + total_new_charges
  end

  def self.by_household_full_name
    joins(household: :community).order("communities.abbrv, households.name")
  end

  def self.with_recent_activity
    where("total_new_credits >= 0.01 OR total_new_charges >= 0.01
      OR current_balance >= 0.01 OR current_balance <= 0.01")
  end

  def self.for(household_id, community_id)
    find_or_create_by!(household_id: household_id, community_id: community_id)
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

  def line_item_added!(line_item)
    if line_item.charge?
      self.total_new_charges += line_item.amount
    else
      self.total_new_credits += line_item.abs_amount
    end
    save!
  end

  def recalculate!
    new_amounts = LineItem.select("
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
end