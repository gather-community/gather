class Account < ActiveRecord::Base
  belongs_to :household, inverse_of: :accounts
  belongs_to :community
  belongs_to :last_invoice, class_name: "Invoice"
  has_many :invoices
  has_many :line_items

  scope :for_community, ->(c){ where(community_id: c.id) }

  delegate :name, :full_name, to: :household, prefix: true
  delegate :due_on, to: :last_invoice, prefix: true, allow_nil: true

  before_save do
    self.balance_due = (due_last_invoice || 0) - total_new_credits
    self.current_balance = balance_due + total_new_charges
  end

  def self.by_household_full_name
    joins(household: :community).order("households.name, communities.abbrv")
  end

  def self.with_recent_activity
    where("total_new_credits >= 0.01 OR total_new_charges >= 0.01 OR current_balance >= 0.01")
  end

  # Updates account for latest invoice. Assumes invoice is latest one since the UI enforces this.
  def invoice_added!(invoice)
    self.last_invoiced_on = invoice.created_on
    self.due_last_invoice = invoice.total_due
    self.last_invoice = invoice
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
      where(invoice_id: nil).to_a.first

    self.last_invoice = invoices.order(:created_at).last
    self.last_invoiced_on = last_invoice.try(:created_on)
    self.due_last_invoice = last_invoice.try(:total_due)
    self.total_new_credits = new_amounts.try(:[], "new_credits").try(:abs) || 0
    self.total_new_charges = new_amounts.try(:[], "new_charges") || 0
    save!
  end
end