class Invoice < ActiveRecord::Base
  TERMS = 30 # days

  belongs_to :household, inverse_of: :invoices
  has_many :line_items, ->{ order(:incurred_on) }, dependent: :nullify
  has_one :account, foreign_key: :last_invoice_id, inverse_of: :last_invoice, dependent: :nullify

  scope :for_community, ->(c){ includes(:household).where("households.community_id = ?", c.id) }

  delegate :community_id, to: :household

  after_create do
    household.account.invoice_added!(self)
  end

  after_destroy do
    household.account.recalculate!
  end

  # Populates the invoice with available line items.
  def populate
    self.line_items = LineItem.where(household: household).uninvoiced.to_a
    self.due_on = Date.today + TERMS
    self.total_due = prev_balance + line_items.map(&:amount).sum
  end

  # Populates the invoice and saves only if the balance is nonzero or there are any line items.
  # Returns whether the invoice was saved.
  def populate!
    populate
    (line_items.any? || total_due.abs >= 0.01) && save!
  end

  def created_on
    created_at.try(:to_date)
  end
end
