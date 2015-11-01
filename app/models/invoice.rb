class Invoice < ActiveRecord::Base
  TERMS = 30 # days

  belongs_to :account, inverse_of: :invoices
  has_many :line_items, ->{ order(:incurred_on) }, dependent: :nullify

  scope :for_community, ->(c){ includes(:household).where("households.community_id = ?", c.id) }

  delegate :community_id, :household, :household_full_name, to: :account

  after_create do
    account.invoice_added!(self)
  end

  before_destroy do
    if account.last_invoice_id == id
      account.last_invoice = nil
      account.save!
    end
  end

  after_destroy do
    account.recalculate!
  end

  # Populates the invoice with available line items.
  # Raises InvoiceError unless the balance is nonzero or there are any line items.
  def populate!
    self.line_items = LineItem.where(account: account).uninvoiced.to_a
    self.due_on = Date.today + TERMS
    self.total_due = prev_balance + line_items.map(&:amount).sum

    if line_items.empty? && total_due.abs < 0.01
      raise InvoiceError.new("Must have line items or a total due.")
    else
      save!
    end
  end

  def created_on
    created_at.try(:to_date)
  end
end

class InvoiceError < StandardError; end